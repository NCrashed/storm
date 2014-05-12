/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Hash table and block table manipulation
*/
module storm.tables;

import storm.callback;
import storm.mpq;
import storm.hashing;
import storm.constants;

/// Attempts to search a free hash entry, or an entry whose names and locale matches
TMPQHash* FindFreeHashEntry(TMPQArchive* ha, uint dwStartIndex, uint dwName1, uint dwName2, LCID lcLocale)
{
    TMPQHash * pDeletedEntry = null;            // If a deleted entry was found in the continuous hash range
    TMPQHash * pFreeEntry = null;               // If a free entry was found in the continuous hash range
    uint dwHashIndexMask = HASH_INDEX_MASK(ha);
    uint dwIndex;

    // Set the initial index
    dwStartIndex = dwIndex = (dwStartIndex & dwHashIndexMask);

    // Search the hash table and return the found entries in the following priority:
    // 1) <MATCHING_ENTRY>
    // 2) <DELETED-ENTRY>
    // 3) <FREE-ENTRY>
    // 4) null
    while(true)
    {
        TMPQHash * pHash = ha.pHashTable + dwIndex;

        // If we found a matching entry, return that one
        if(pHash.dwName1 == dwName1 && pHash.dwName2 == dwName2 && pHash.lcLocale == lcLocale)
            return pHash;

        // If we found a deleted entry, remember it but keep searching
        if(pHash.dwBlockIndex == HASH_ENTRY_DELETED && pDeletedEntry is null)
            pDeletedEntry = pHash;

        // If we found a free entry, we need to stop searching
        if(pHash.dwBlockIndex == HASH_ENTRY_FREE)
        {
            pFreeEntry = pHash;
            break;
        }

        // Move to the next hash entry.
        // If we reached the starting entry, it's failure.
        dwIndex = (dwIndex + 1) & dwHashIndexMask;
        if(dwIndex == dwStartIndex)
            break;
    }

    // If we found a deleted entry, return that one preferentially
    return (pDeletedEntry !is null) ? pDeletedEntry : pFreeEntry;
}

/// Retrieves the first hash entry for the given file.
/// Every locale version of a file has its own hash entry
TMPQHash* GetFirstHashEntry(TMPQArchive* ha, string szFileName)
{
    uint dwHashIndexMask = HASH_INDEX_MASK(ha);
    uint dwStartIndex = ha.pfnHashString(szFileName, MPQ_HASH_TABLE_INDEX);
    uint dwName1 = ha.pfnHashString(szFileName, MPQ_HASH_NAME_A);
    uint dwName2 = ha.pfnHashString(szFileName, MPQ_HASH_NAME_B);
    uint dwIndex;

    // Set the initial index
    dwStartIndex = dwIndex = (dwStartIndex & dwHashIndexMask);

    // Search the hash table
    while(true)
    {
        TMPQHash * pHash = ha.pHashTable + dwIndex;

        // If the entry matches, we found it.
        if(pHash.dwName1 == dwName1 && pHash.dwName2 == dwName2 && pHash.dwBlockIndex < ha.dwFileTableSize)
            return pHash;

        // If that hash entry is a free entry, it means we haven't found the file
        if(pHash.dwBlockIndex == HASH_ENTRY_FREE)
            return null;

        // Move to the next hash entry. Stop searching
        // if we got reached the original hash entry
        dwIndex = (dwIndex + 1) & dwHashIndexMask;
        if(dwIndex == dwStartIndex)
            return null;
    }
}

TMPQHash* GetNextHashEntry(TMPQArchive* ha, TMPQHash* pFirstHash, TMPQHash* pHash)
{
    uint dwHashIndexMask = HASH_INDEX_MASK(ha);
    uint dwStartIndex = cast(uint)(pFirstHash - ha.pHashTable);
    uint dwName1 = pHash.dwName1;
    uint dwName2 = pHash.dwName2;
    uint dwIndex = cast(uint)(pHash - ha.pHashTable);

    // Now go for any next entry that follows the pHash,
    // until either free hash entry was found, or the start entry was reached
    while(true)
    {
        // Move to the next hash entry. Stop searching
        // if we got reached the original hash entry
        dwIndex = (dwIndex + 1) & dwHashIndexMask;
        if(dwIndex == dwStartIndex)
            return null;
        pHash = ha.pHashTable + dwIndex;

        // If the entry matches, we found it.
        if(pHash.dwName1 == dwName1 && pHash.dwName2 == dwName2 && pHash.dwBlockIndex < ha.pHeader.dwBlockTableSize)
            return pHash;

        // If that hash entry is a free entry, it means we haven't found the file
        if(pHash.dwBlockIndex == HASH_ENTRY_FREE)
            return null;
    }
}

// Allocates an entry in the hash table
TMPQHash* AllocateHashEntry(
    TMPQArchive* ha,
    TFileEntry* pFileEntry)
{
    TMPQHash* pHash;
    uint dwStartIndex = ha.pfnHashString(pFileEntry.szFileName, MPQ_HASH_TABLE_INDEX);
    uint dwName1 = ha.pfnHashString(pFileEntry.szFileName, MPQ_HASH_NAME_A);
    uint dwName2 = ha.pfnHashString(pFileEntry.szFileName, MPQ_HASH_NAME_B);

    // Attempt to find a free hash entry
    pHash = FindFreeHashEntry(ha, dwStartIndex, dwName1, dwName2, pFileEntry.lcLocale);
    if(pHash !is null)
    {
        // Fill the free hash entry
        pHash.dwName1      = dwName1;
        pHash.dwName2      = dwName2;
        pHash.lcLocale     = pFileEntry.lcLocale;
        pHash.wPlatform    = pFileEntry.wPlatform;
        pHash.dwBlockIndex = cast(uint)(pFileEntry - ha.pFileTable);

        // Fill the hash index in the file entry
        pFileEntry.dwHashIndex = cast(uint)(pHash - ha.pHashTable);
    }

    return pHash;
}

/// Finds a free space in the MPQ where to store next data
/// The free space begins beyond the file that is stored at the furthest
/// position in the MPQ.
ulong FindFreeMpqSpace(TMPQArchive* ha)
{
    TMPQHeader * pHeader = ha.pHeader;
    TFileEntry * pFileTableEnd = ha.pFileTable + ha.dwFileTableSize;
    TFileEntry * pFileEntry;
    ulong FreeSpacePos = ha.pHeader.dwHeaderSize;
    uint dwChunkCount;

    // Parse the entire block table
    for(pFileEntry = ha.pFileTable; pFileEntry < pFileTableEnd; pFileEntry++)
    {
        // Only take existing files with nonzero size
        if((pFileEntry.dwFlags & MPQ_FILE_EXISTS) && (pFileEntry.dwCmpSize != 0))
        {
            // If the end of the file is bigger than current MPQ table pos, update it
            if((pFileEntry.ByteOffset + pFileEntry.dwCmpSize) > FreeSpacePos)
            {
                // Get the end of the file data
                FreeSpacePos = pFileEntry.ByteOffset + pFileEntry.dwCmpSize;

                // Add the MD5 chunks, if present
                if(pHeader.dwRawChunkSize != 0 && pFileEntry.dwCmpSize != 0)
                {
                    dwChunkCount = ((pFileEntry.dwCmpSize - 1) / pHeader.dwRawChunkSize) + 1;
                    FreeSpacePos += dwChunkCount * MD5_DIGEST_SIZE;
                }
            }
        }
    }

    // Give the free space position to the caller
    return FreeSpacePos;
}
