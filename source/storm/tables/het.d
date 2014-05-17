/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Support for HET table
*/
module storm.tables.het;

import storm.mpq;
import storm.bitarray;
import storm.hashing;
import storm.errors;
import storm.bitarray;

// Signatures for HET and BET table
/// 'HET\x1a'
enum HET_TABLE_SIGNATURE       = 0x1A544548; 
/// NameHash1 value for a deleted entry
enum HET_ENTRY_DELETED               = 0x80;  
/// NameHash1 value for free entry
enum HET_ENTRY_FREE                  = 0x00;  

void CreateHetHeader(
    TMPQHetTable pHetTable,
    out TMPQHetHeader pHetHeader)
{
    // Fill the common header
    pHetHeader.ExtHdr.dwSignature  = HET_TABLE_SIGNATURE;
    pHetHeader.ExtHdr.dwVersion    = 1;
    pHetHeader.ExtHdr.dwDataSize   = 0;

    // Fill the HET header
    pHetHeader.dwEntryCount        = pHetTable.dwEntryCount;
    pHetHeader.dwTotalCount        = pHetTable.dwTotalCount;
    pHetHeader.dwNameHashBitSize   = pHetTable.dwNameHashBitSize;
    pHetHeader.dwIndexSizeTotal    = pHetTable.dwIndexSizeTotal;
    pHetHeader.dwIndexSizeExtra    = pHetTable.dwIndexSizeExtra;
    pHetHeader.dwIndexSize         = pHetTable.dwIndexSize;
    pHetHeader.dwIndexTableSize    = ((pHetHeader.dwIndexSizeTotal * pHetTable.dwTotalCount) + 7) / 8;

    // Calculate the total size needed for holding HET table
    pHetHeader.ExtHdr.dwDataSize =
    pHetHeader.dwTableSize = cast(uint)(TMPQHetHeader.sizeof - TMPQExtHeader.sizeof +
                              pHetHeader.dwTotalCount +
                              pHetHeader.dwIndexTableSize);
}

TMPQHetTable CreateHetTable(uint dwEntryCount, uint dwTotalCount, size_t dwNameHashBitSize, ubyte[] pbSrcData)
{
    TMPQHetTable pHetTable = new TMPQHetTable;

    // Hash sizes less than 0x40 bits are not tested
    assert(dwNameHashBitSize == 0x40);

    // Calculate masks
    pHetTable.AndMask64 = ((dwNameHashBitSize != 0x40) ? (cast(ulong)1 << dwNameHashBitSize) : 0) - 1;
    pHetTable.OrMask64 = cast(ulong)1 << (dwNameHashBitSize - 1);

    // If the total count is not entered, use default
    if(dwTotalCount == 0)
        dwTotalCount = (dwEntryCount * 4) / 3;

    // Store the HET table parameters
    pHetTable.dwEntryCount        = dwEntryCount;
    pHetTable.dwTotalCount        = dwTotalCount;
    pHetTable.dwNameHashBitSize   = cast(uint)dwNameHashBitSize;
    pHetTable.dwIndexSizeTotal    = GetNecessaryBitCount(dwEntryCount);
    pHetTable.dwIndexSizeExtra    = 0;
    pHetTable.dwIndexSize         = pHetTable.dwIndexSizeTotal;

    // Allocate array of hashes
    pHetTable.pNameHashes = new ubyte[dwTotalCount];
    
    // Allocate the bit array for file indexes
    pHetTable.pBetIndexes = CreateBitArray(dwTotalCount * pHetTable.dwIndexSizeTotal, 0xFF);
    
    // Initialize the HET table from the source data (if given)
    if(pbSrcData !is null)
    {
        // Copy the name hashes
        pHetTable.pNameHashes[0 .. dwTotalCount] = pbSrcData[];

        // Copy the file indexes
        pHetTable.pBetIndexes.elements[0 .. $] 
        	= pbSrcData[dwTotalCount .. $];
    }
    
    // Return the result HET table
    return pHetTable;
}

int InsertHetEntry(TMPQHetTable pHetTable, ulong FileNameHash, uint dwFileIndex)
{
    uint StartIndex;
    uint Index;
    ubyte NameHash1;

    // Get the start index and the high 8 bits of the name hash
    StartIndex = Index = cast(uint)(FileNameHash % pHetTable.dwEntryCount);
    NameHash1 = cast(ubyte)(FileNameHash >> (pHetTable.dwNameHashBitSize - 8));

    // Find a place where to put it
    for(;;)
    {
        // Did we find a free HET entry?
        if(pHetTable.pNameHashes[Index] == HET_ENTRY_FREE)
        {
            // Set the entry in the name hash table
            pHetTable.pNameHashes[Index] = NameHash1;

            // Set the entry in the file index table
            SetBits(pHetTable.pBetIndexes, pHetTable.dwIndexSizeTotal * Index,
                                           pHetTable.dwIndexSize,
                                           cast(ubyte[])((&dwFileIndex)[0 .. 1]));
            return ERROR_SUCCESS;
        }

        // Move to the next entry in the HET table
        // If we came to the start index again, we are done
        Index = (Index + 1) % pHetTable.dwEntryCount;
        if(Index == StartIndex)
            break;
    }

    // No space in the HET table. Should never happen,
    // because the HET table is created according to the number of files
    //assert(false);
    return ERROR_DISK_FULL;
}

TMPQHetTable TranslateHetTable(TMPQHetHeader pHetHeader)
{
    TMPQHetTable pHetTable;
    ubyte[] pbSrcData = pHetHeader.pbSrcData;

    // Sanity check
    assert(pHetHeader.ExtHdr.dwSignature == HET_TABLE_SIGNATURE);
    assert(pHetHeader.ExtHdr.dwVersion == 1);

    // Verify size of the HET table
    if(pHetHeader.ExtHdr.dwDataSize >= (TMPQHetHeader.Data.sizeof - TMPQExtHeader.sizeof))
    {
        // Verify the size of the table in the header
        if(pHetHeader.dwTableSize == pHetHeader.ExtHdr.dwDataSize)
        {
            // The size of the HET table must be sum of header, hash and index table size
            assert((TMPQHetHeader.Data.sizeof - TMPQExtHeader.sizeof + pHetHeader.dwTotalCount + pHetHeader.dwIndexTableSize) == pHetHeader.dwTableSize);

            // So far, all MPQs with HET Table have had total number of entries equal to 4/3 of file count
            // Exception: "2010 - Starcraft II\!maps\Tya's Zerg Defense (unprotected).SC2Map"
//          assert(((pHetHeader.dwEntryCount * 4) / 3) == pHetHeader.dwTotalCount);

            // The size of one index is predictable as well
            assert(GetNecessaryBitCount(pHetHeader.dwEntryCount) == pHetHeader.dwIndexSizeTotal);

            // The size of index table (in entries) is expected
            // to be the same like the hash table size (in ubytes)
            assert(((pHetHeader.dwTotalCount * pHetHeader.dwIndexSizeTotal) + 7) / 8 == pHetHeader.dwIndexTableSize);
            
            // Create translated table
            pHetTable = CreateHetTable(pHetHeader.dwEntryCount, pHetHeader.dwTotalCount, pHetHeader.dwNameHashBitSize, pbSrcData);
            if(pHetTable !is null)
            {
                // Now the sizes in the hash table should be already set
                assert(pHetTable.dwEntryCount     == pHetHeader.dwEntryCount);
                assert(pHetTable.dwTotalCount     == pHetHeader.dwTotalCount);
                assert(pHetTable.dwIndexSizeTotal == pHetHeader.dwIndexSizeTotal);

                // Copy the missing variables
                pHetTable.dwIndexSizeExtra = pHetHeader.dwIndexSizeExtra;
                pHetTable.dwIndexSize      = pHetHeader.dwIndexSize;
            }
        }
    }

    return pHetTable;
}

TMPQHetHeader TranslateHetTable(TMPQHetTable pHetTable, out ulong pcbHetTable)
{
    TMPQHetHeader pHetHeader = null;
    TMPQHetHeader HetHeader;
    
    // Prepare header of the HET table
    CreateHetHeader(pHetTable, HetHeader);

    // Allocate space for the linear table
    //pbLinearTable = STORM_ALLOC(ubyte, sizeof(TMPQExtHeader) + HetHeader.dwTableSize);
    pHetHeader = new TMPQHetHeader;
    pHetHeader.pbSrcData = new ubyte[HetHeader.pbSrcData.length];

    // Copy the table header
    (cast(ubyte*)&pHetHeader.data)[0 .. pHetHeader.Data.sizeof] 
    	= (cast(ubyte*)&HetHeader.data)[0 .. pHetHeader.Data.sizeof];

    assert(pHetHeader.pbSrcData.length == pHetTable.dwTotalCount + HetHeader.dwIndexTableSize);
    
    // Copy the array of name hashes
    // Copy the bit array of BET indexes
    pHetHeader.pbSrcData = HetHeader.pbSrcData.dup;

    // Calculate the total size of the table, including the TMPQExtHeader
    pcbHetTable = cast(ulong)(TMPQExtHeader.sizeof + HetHeader.dwTableSize);

    return pHetHeader;
}

uint GetFileIndex_Het(TMPQArchive ha, string szFileName)
{
    TMPQHetTable pHetTable = ha.pHetTable;
    ulong FileNameHash;
    uint StartIndex;
    uint Index;
    ubyte NameHash1;                 // Upper 8 bits of the masked file name hash

    // If there are no entries in the HET table, do nothing
    if(pHetTable.dwEntryCount == 0)
        return HASH_ENTRY_FREE;

    // Do nothing if the MPQ has no HET table
    assert(ha.pHetTable !is null);

    // Calculate 64-bit hash of the file name
    FileNameHash = (HashStringJenkins(szFileName) & pHetTable.AndMask64) | pHetTable.OrMask64;

    // Split the file name hash into two parts:
    // NameHash1: The highest 8 bits of the name hash
    // NameHash2: File name hash limited to hash size
    // Note: Our file table contains full name hash, no need to cut the high 8 bits before comparison
    NameHash1 = cast(ubyte)(FileNameHash >> (pHetTable.dwNameHashBitSize - 8));

    // Calculate the starting index to the hash table
    StartIndex = Index = cast(uint)(FileNameHash % pHetTable.dwEntryCount);

    // Go through HET table until we find a terminator
    while(pHetTable.pNameHashes[Index] != HET_ENTRY_FREE)
    {
        // Did we find a match ?
        if(pHetTable.pNameHashes[Index] == NameHash1)
        {
            uint dwFileIndex = 0;

            assert((cast(ubyte[])(&dwFileIndex)[0 .. 1]).length == 4);
            
            // Get the file index
            GetBits(pHetTable.pBetIndexes, pHetTable.dwIndexSizeTotal * Index,
                                           pHetTable.dwIndexSize,
                                           cast(ubyte[])(&dwFileIndex)[0 .. 1]);
            //
            // TODO: This condition only happens when we are opening a MPQ
            // where some files were deleted by StormLib. Perhaps 
            // we should not allow shrinking of the file table in MPQs v 4.0?
            // assert(dwFileIndex <= ha.dwFileTableSize);
            //

            // Verify the FileNameHash against the entry in the table of name hashes
            if(dwFileIndex <= ha.dwFileTableSize && ha.pFileTable[dwFileIndex].FileNameHash == FileNameHash)
                return dwFileIndex;
        }

        // Move to the next entry in the HET table
        // If we came to the start index again, we are done
        Index = (Index + 1) % pHetTable.dwEntryCount;
        if(Index == StartIndex)
            break;
    }

    // File not found
    return HASH_ENTRY_FREE;
}

void FreeHetTable(ref TMPQHetTable pHetTable)
{
    if(pHetTable !is null)
    {
        if(pHetTable.pNameHashes !is null)
            pHetTable.pNameHashes = null;

        pHetTable = null;
    }
}