/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Common functions - MPQ File
*/
module storm.common;

import storm.mpq;
import storm.swapping;
import storm.errors;
import storm.filestream;
import storm.encrypt;
import storm.hashing;
import storm.constants;
import storm.tables.het;

enum ID_MPQ_FILE            = 0x46494c45;

//-----------------------------------------------------------------------------
// Conversion to uppercase/lowercase

/// Converts ASCII characters to lowercase
/// Converts slash (0x2F) to backslash (0x5C)
immutable ubyte[256] AsciiToLowerTable = 
[
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x5C, 
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 
    0x40, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F, 
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 
    0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF, 
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
    0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF
];

/// Converts ASCII characters to uppercase
/// Converts slash (0x2F) to backslash (0x5C)
immutable ubyte[256] AsciiToUpperTable = 
[
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x5C, 
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 
    0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 
    0x60, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 
    0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F, 
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 
    0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF, 
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
    0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF
];

/// Converts ASCII characters to uppercase
/// Does NOT convert slash (0x2F) to backslash (0x5C)
immutable ubyte[256] AsciiToUpperTable_Slash = 
[
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 
    0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 
    0x60, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 
    0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F, 
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 
    0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF, 
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
    0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF
];

TMPQFile CreateFileHandle(TMPQArchive ha, TFileEntry pFileEntry)
{
    TMPQFile hf;

    // Allocate space for TMPQFile
    hf = new TMPQFile;
    // Fill the file structure
    hf.dwMagic = ID_MPQ_FILE;
    hf.pStream = null;
    hf.ha = ha;

    // If the called entered a file entry, we also copy informations from the file entry
    if(ha !is null && pFileEntry !is null)
    {
        // Set the raw position and MPQ position
        hf.RawFilePos = ha.MpqPos + pFileEntry.ByteOffset;
        hf.MpqFilePos = pFileEntry.ByteOffset;

        // Set the data size
        hf.dwDataSize = pFileEntry.dwFileSize;
        hf.pFileEntry = pFileEntry;
    }

    return hf;
}

//// Loads a table from MPQ.
//// Can be used for hash table, block table, sector offset table or sector checksum table
ubyte[] LoadMpqTable(
    TMPQArchive ha,
    ulong ByteOffset,
    size_t dwCompressedSize,
    size_t dwTableSize,
    uint dwKey)
{
    ubyte[] pbCompressed = null;
    ubyte[] pbMpqTable;
    ubyte[] pbToRead;
    size_t dwBytesToRead = dwCompressedSize;
    size_t dwValidLength = dwTableSize;
    int nError = ERROR_SUCCESS;

    // Allocate the MPQ table
    pbMpqTable = pbToRead = new ubyte[dwTableSize];
    
    // Check if the MPQ table is encrypted
    if(dwCompressedSize < dwTableSize)
    {
        // Allocate temporary buffer for holding compressed data
        pbCompressed = pbToRead = new ubyte[dwCompressedSize];
    }

    // If everything succeeded, read the raw table form the MPQ
    if(FileStream_Read(ha.pStream, &ByteOffset, pbToRead[0 .. dwBytesToRead]))
    {
        // First of all, decrypt the table
        if(dwKey != 0)
        {
            BSWAP_ARRAY32_UNSIGNED(pbToRead[0 .. dwCompressedSize]);
            DecryptMpqBlock(cast(uint[])pbToRead[0 .. dwCompressedSize], dwKey);
            BSWAP_ARRAY32_UNSIGNED(pbToRead[0 .. dwCompressedSize]);
        }

        // If the table is compressed, decompress it
        if(dwCompressedSize < dwTableSize)
        {
            int cbOutBuffer = cast(int)dwTableSize;
            int cbInBuffer = cast(int)dwCompressedSize;

            if(!SCompDecompress2(pbMpqTable, &cbOutBuffer, pbCompressed, cbInBuffer))
                nError = GetLastError();
        }

        // Make sure that the table is properly byte-swapped
        BSWAP_ARRAY32_UNSIGNED(pbMpqTable);

        // If the table was not fully readed, fill the rest with zeros
        if(dwValidLength < dwTableSize)
            pbMpqTable[dwValidLength .. $] = 0;
    }
    else
    {
        nError = GetLastError();
    }

    // Return the MPQ table
    return pbMpqTable;
}

void CalculateRawSectorOffset(
    out ulong RawFilePos, 
    TMPQFile hf,
    size_t dwSectorOffset)
{
    //
    // Some MPQ protectors place the sector offset table after the actual file data.
    // Sector offsets in the sector offset table are negative. When added
    // to MPQ file offset from the block table entry, the result is a correct
    // position of the file data in the MPQ.
    //
    // The position of sector table must be always within the MPQ, however.
    // When a negative sector offset is found, we make sure that we make the addition
    // just in 32-bits, and then add the MPQ offset.
    //

    if(dwSectorOffset & 0x80000000)
    {
        RawFilePos = hf.ha.MpqPos + (cast(uint)hf.pFileEntry.ByteOffset + dwSectorOffset);
    }
    else
    {
        RawFilePos = hf.RawFilePos + dwSectorOffset;
    }

    // We also have to add patch header size, if patch header is present
    if(hf.pPatchInfo !is null)
        RawFilePos += hf.pPatchInfo.dwLength;
}

ubyte[] AllocateMd5Buffer(
    size_t dwRawDataSize,
    size_t dwChunkSize)
{
    ubyte[] md5_array;
    size_t cbMd5Size;

    // Sanity check
    assert(dwRawDataSize != 0);
    assert(dwChunkSize != 0);

    // Calculate how many MD5's we will calculate
    cbMd5Size = (((dwRawDataSize - 1) / dwChunkSize) + 1) * MD5_DIGEST_SIZE;

    // Allocate space for array or MD5s
    md5_array = new ubyte[cbMd5Size];

    return md5_array;
}

//// Allocates sector buffer and sector offset table
int AllocateSectorBuffer(TMPQFile hf)
{
    TMPQArchive ha = hf.ha;

    // Caller of AllocateSectorBuffer must ensure these
    assert(hf.pbFileSector.length == 0);
    assert(hf.pFileEntry !is null);
    assert(hf.ha !is null);

    // Don't allocate anything if the file has zero size
    if(hf.pFileEntry.dwFileSize == 0 || hf.dwDataSize == 0)
        return ERROR_SUCCESS;

    // Determine the file sector size and allocate buffer for it
    hf.dwSectorSize = (hf.pFileEntry.dwFlags & MPQ_FILE_SINGLE_UNIT) ? hf.dwDataSize : ha.dwSectorSize;
    hf.pbFileSector = new ubyte[hf.dwSectorSize];
    hf.dwSectorOffs = SFILE_INVALID_POS;

    // Return result
    return (hf.pbFileSector !is null) ? cast(int)ERROR_SUCCESS : cast(int)ERROR_NOT_ENOUGH_MEMORY;
}

//// Allocates sector offset table
int AllocatePatchInfo(TMPQFile hf, bool bLoadFromFile)
{
    TMPQArchive ha = hf.ha;

    // The following conditions must be true
    assert(hf.pFileEntry.dwFlags & MPQ_FILE_PATCH_FILE);
    assert(hf.pPatchInfo is null);

    // Allocate space for patch header. Start with default size,
    // and if its size if bigger, then we reload them
    hf.pPatchInfo = new TPatchInfo;
    enum dataLength = TPatchInfo.Data.sizeof;
    size_t dwLength = dataLength;
    
    // Do we have to load the patch header from the file ?
    if(bLoadFromFile)
    {
        
        // Load the patch header
        if(!FileStream_Read(ha.pStream, &hf.RawFilePos, (cast(ubyte*)&hf.pPatchInfo.data)[0 .. dataLength]))
        {
            // Free the patch info
            hf.pPatchInfo = null;
            return GetLastError();
        }

        // Perform necessary swapping
        hf.pPatchInfo.dwLength = BSWAP_INT32_UNSIGNED(hf.pPatchInfo.dwLength);
        hf.pPatchInfo.dwFlags = BSWAP_INT32_UNSIGNED(hf.pPatchInfo.dwFlags);
        hf.pPatchInfo.dwDataSize = BSWAP_INT32_UNSIGNED(hf.pPatchInfo.dwDataSize);

        // Verify the size of the patch header
        // If it's not default size, we have to reload them
        if(hf.pPatchInfo.dwLength > dataLength)
        {
            // Free the patch info
            dwLength = hf.pPatchInfo.dwLength;

            // If the length is out of all possible ranges, fail the operation
            if(dwLength > 0x400)
                return ERROR_FILE_CORRUPT;
                
            hf.pPatchInfo.pSectorTable = new ubyte[dwLength - dataLength];
            if(!FileStream_Read(ha.pStream, &hf.RawFilePos, hf.pPatchInfo.pSectorTable))
            {
                // Free the patch info
                hf.pPatchInfo = null;
                return GetLastError();
            }
        }

        // Patch file data size according to the patch header
        hf.dwDataSize = hf.pPatchInfo.dwDataSize;
    }

    // Save the final length to the patch header
    hf.pPatchInfo.dwLength = cast(uint)dwLength;
    hf.pPatchInfo.dwFlags  = 0x80000000;
    return ERROR_SUCCESS;
}

//// Allocates sector offset table
int AllocateSectorOffsets(TMPQFile hf, bool bLoadFromFile)
{
    TMPQArchive ha = hf.ha;
    TFileEntry pFileEntry = hf.pFileEntry;
    size_t dwSectorOffsLen;
    bool bSectorOffsetTableCorrupt = false;

    // Caller of AllocateSectorOffsets must ensure these
    assert(hf.SectorOffsets.length == 0);
    assert(hf.pFileEntry !is null);
    assert(hf.dwDataSize != 0);
    assert(hf.ha !is null);

    // If the file is stored as single unit, just set number of sectors to 1
    if(pFileEntry.dwFlags & MPQ_FILE_SINGLE_UNIT)
    {
        hf.dwSectorCount = 1;
        return ERROR_SUCCESS;
    }

    // Calculate the number of data sectors
    // Note that this doesn't work if the file size is zero
    hf.dwSectorCount = ((hf.dwDataSize - 1) / hf.dwSectorSize) + 1;

    // Calculate the number of file sectors
    dwSectorOffsLen = (hf.dwSectorCount + 1) * uint.sizeof;
    
    // If MPQ_FILE_SECTOR_CRC flag is set, there will either be extra uint
    // or an array of MD5's. Either way, we read at least 4 bytes more
    // in order to save additional read from the file.
    if(pFileEntry.dwFlags & MPQ_FILE_SECTOR_CRC)
        dwSectorOffsLen += uint.sizeof;

    // Only allocate and load the table if the file is compressed
    if(pFileEntry.dwFlags & MPQ_FILE_COMPRESS_MASK)
    {
        // Allocate the sector offset table
        hf.SectorOffsets = new uint[dwSectorOffsLen / uint.sizeof];

        // Only read from the file if we are supposed to do so
        if(bLoadFromFile)
        {
            ulong RawFilePos = hf.RawFilePos;

            if(hf.pPatchInfo !is null)
                RawFilePos += hf.pPatchInfo.dwLength;

            // Load the sector offsets from the file
            if(!FileStream_Read(ha.pStream, &RawFilePos, cast(ubyte[])hf.SectorOffsets))
            {
                // Free the sector offsets
                hf.SectorOffsets = null;
                return GetLastError();
            }

            // Swap the sector positions
            BSWAP_ARRAY32_UNSIGNED(cast(ubyte[])hf.SectorOffsets);

            // Decrypt loaded sector positions if necessary
            if(pFileEntry.dwFlags & MPQ_FILE_ENCRYPTED)
            {
                // If we don't know the file key, try to find it.
                if(hf.dwFileKey == 0)
                {
                    hf.dwFileKey = DetectFileKeyBySectorSize(hf.SectorOffsets, ha.dwSectorSize, dwSectorOffsLen);
                    if(hf.dwFileKey == 0)
                    {
                        hf.SectorOffsets = null;
                        return ERROR_UNKNOWN_FILE_KEY;
                    }
                }

                // Decrypt sector positions
                DecryptMpqBlock(hf.SectorOffsets, hf.dwFileKey - 1);
            }

            //
            // Validate the sector offset table
            //
            // Note: Some MPQ protectors put the actual file data before the sector offset table.
            // In this case, the sector offsets are negative (> 0x80000000).
            //

            for(uint i = 0; i < hf.dwSectorCount; i++)
            {
                uint dwSectorOffset1 = hf.SectorOffsets[i+1];
                uint dwSectorOffset0 = hf.SectorOffsets[i];

                // Every following sector offset must be bigger than the previous one
                if(dwSectorOffset1 <= dwSectorOffset0)
                {
                    bSectorOffsetTableCorrupt = true;
                    break;
                }

                // The sector size must not be bigger than compressed file size
                if((dwSectorOffset1 - dwSectorOffset0) > pFileEntry.dwCmpSize)
                {
                    bSectorOffsetTableCorrupt = true;
                    break;
                }
            }

            // If data corruption detected, free the sector offset table
            if(bSectorOffsetTableCorrupt)
            {
                hf.SectorOffsets = null;
                return ERROR_FILE_CORRUPT;
            }

            //
            // There may be various extra DWORDs loaded after the sector offset table.
            // They are mostly empty on WoW release MPQs, but on MPQs from PTR,
            // they contain random non-zero data. Their meaning is unknown.
            //
            // These extra values are, however, include in the dwCmpSize in the file
            // table. We cannot ignore them, because compacting archive would fail
            // 

            if(hf.SectorOffsets[0] > dwSectorOffsLen)
            {
                auto extra = new uint[(hf.SectorOffsets[0] - dwSectorOffsLen)/4];
                dwSectorOffsLen = hf.SectorOffsets[0];
                
                if(!FileStream_Read(ha.pStream, &RawFilePos, cast(ubyte[])extra))
                {
                    // Free the sector offsets
                    hf.SectorOffsets = null;
                    return GetLastError();
                }
                
                // Swap the sector positions
                BSWAP_ARRAY32_UNSIGNED(cast(ubyte[])extra);
    
                // Decrypt loaded sector positions if necessary
                if(pFileEntry.dwFlags & MPQ_FILE_ENCRYPTED)
                {
                    // Decrypt sector positions
                    DecryptMpqBlock(extra, hf.dwFileKey - 1);
                }
            
                hf.SectorOffsets ~= extra;
            }
        }
        else
        {
            hf.SectorOffsets[0] = cast(uint)dwSectorOffsLen;
        }
    }

    return ERROR_SUCCESS;
}

int AllocateSectorChecksums(TMPQFile hf, bool bLoadFromFile)
{
    TMPQArchive ha = hf.ha;
    TFileEntry pFileEntry = hf.pFileEntry;
    ulong RawFilePos;
    uint dwCompressedSize = 0;
    size_t dwExpectedSize;
    size_t dwCrcOffset;                      // Offset of the CRC table, relative to file offset in the MPQ
    size_t dwCrcSize;

    // Caller of AllocateSectorChecksums must ensure these
    assert(hf.SectorChksums.length == 0);
    assert(hf.SectorOffsets !is null);
    assert(hf.pFileEntry !is null);
    assert(hf.ha !is null);

    // Single unit files don't have sector checksums
    if(pFileEntry.dwFlags & MPQ_FILE_SINGLE_UNIT)
        return ERROR_SUCCESS;

    // Caller must ensure that we are only called when we have sector checksums
    assert(pFileEntry.dwFlags & MPQ_FILE_SECTOR_CRC);

    // 
    // Older MPQs store an array of CRC32's after
    // the raw file data in the MPQ.
    //
    // In newer MPQs, the (since Cataclysm BETA) the (attributes) file
    // contains additional 32-bit values beyond the sector table.
    // Their number depends on size of the (attributes), but their
    // meaning is unknown. They are usually zeroed in retail game files,
    // but contain some sort of checksum in BETA MPQs
    //

    // Does the size of the file table match with the CRC32-based checksums?
    dwExpectedSize = (hf.dwSectorCount + 2) * uint.sizeof;
    if(hf.SectorOffsets[0] != 0 && hf.SectorOffsets[0] == dwExpectedSize)
    {
        // If we are not loading from the MPQ file, we just allocate the sector table
        // In that case, do not check any sizes
        if(bLoadFromFile == false)
        {
            hf.SectorChksums = new uint[hf.dwSectorCount];
            return ERROR_SUCCESS;
        }
        else
        {
            // Is there valid size of the sector checksums?
            if(hf.SectorOffsets[hf.dwSectorCount + 1] >= hf.SectorOffsets[hf.dwSectorCount])
                dwCompressedSize = hf.SectorOffsets[hf.dwSectorCount + 1] - hf.SectorOffsets[hf.dwSectorCount];

            // Ignore cases when the length is too small or too big.
            if(dwCompressedSize < uint.sizeof || dwCompressedSize > hf.dwSectorSize)
                return ERROR_SUCCESS;

            // Calculate offset of the CRC table
            dwCrcSize = hf.dwSectorCount * uint.sizeof;
            dwCrcOffset = hf.SectorOffsets[hf.dwSectorCount];
            CalculateRawSectorOffset(RawFilePos, hf, dwCrcOffset); 

            // Now read the table from the MPQ
            hf.SectorChksums = cast(uint[])LoadMpqTable(ha, RawFilePos, dwCompressedSize, dwCrcSize, 0);
        }
    }

    // If the size doesn't match, we ignore sector checksums
    return ERROR_SUCCESS;
}

int WritePatchInfo(TMPQFile hf)
{
    TMPQArchive ha = hf.ha;
    TPatchInfo pPatchInfo = hf.pPatchInfo;

    // The caller must make sure that this function is only called
    // when the following is true.
    assert(hf.pFileEntry.dwFlags & MPQ_FILE_PATCH_FILE);
    assert(pPatchInfo !is null);

    BSWAP_ARRAY32_UNSIGNED((cast(ubyte*)&pPatchInfo.data)[0 .. 3 * uint.sizeof]);
    if(!FileStream_Write(ha.pStream, &hf.RawFilePos, (cast(ubyte*)&pPatchInfo.data)[0 .. TPatchInfo.Data.sizeof]))
        return GetLastError();

    return ERROR_SUCCESS;
}

int WriteSectorOffsets(TMPQFile hf)
{
    TMPQArchive ha = hf.ha;
    TFileEntry pFileEntry = hf.pFileEntry;
    ulong RawFilePos = hf.RawFilePos;

    // The caller must make sure that this function is only called
    // when the following is true.
    assert(hf.pFileEntry.dwFlags & MPQ_FILE_COMPRESS_MASK);
    assert(hf.SectorOffsets !is null);

    // If file is encrypted, sector positions are also encrypted
    if(pFileEntry.dwFlags & MPQ_FILE_ENCRYPTED)
        EncryptMpqBlock(hf.SectorOffsets, hf.dwFileKey - 1);
    BSWAP_ARRAY32_UNSIGNED(cast(ubyte[])hf.SectorOffsets);

    // Adjust sector offset table position, if we also have patch info
    if(hf.pPatchInfo !is null)
        RawFilePos += hf.pPatchInfo.dwLength;

    // Write sector offsets to the archive
    if(!FileStream_Write(ha.pStream, &RawFilePos, cast(ubyte[])hf.SectorOffsets))
        return GetLastError();
    
    // Not necessary, as the sector checksums
    // are going to be freed when this is done.
//  BSWAP_ARRAY32_UNSIGNED(hf.SectorOffsets, dwSectorOffsLen);
    return ERROR_SUCCESS;
}

int WriteSectorChecksums(TMPQFile hf)
{
    TMPQArchive ha = hf.ha;
    ulong RawFilePos;
    TFileEntry pFileEntry = hf.pFileEntry;
    ubyte[] pbCompressed;
    size_t dwCompressedSize = 0;
    size_t dwCrcSize;
    int nOutSize;
    int nError = ERROR_SUCCESS;

    // The caller must make sure that this function is only called
    // when the following is true.
    assert(hf.pFileEntry.dwFlags & MPQ_FILE_SECTOR_CRC);
    assert(hf.SectorOffsets !is null);
    assert(hf.SectorChksums !is null);

    // If the MPQ has MD5 of each raw data chunk,
    // we leave sector offsets empty
    if(ha.pHeader.dwRawChunkSize != 0)
    {
        hf.SectorOffsets[hf.dwSectorCount + 1] = hf.SectorOffsets[hf.dwSectorCount]; // TODO: check overfloat!
        return ERROR_SUCCESS;
    }

    // Calculate size of the checksum array
    dwCrcSize = hf.dwSectorCount * uint.sizeof;

    // Allocate buffer for compressed sector CRCs.
    pbCompressed = new ubyte[dwCrcSize];

    // Perform the compression
    BSWAP_ARRAY32_UNSIGNED(cast(ubyte[])hf.SectorChksums);

    nOutSize = cast(int)dwCrcSize;
    SCompCompress(pbCompressed, nOutSize, hf.SectorChksums, MPQ_COMPRESSION_ZLIB, 0, 0);
    dwCompressedSize = cast(size_t)nOutSize;

    // Write the sector CRCs to the archive
    RawFilePos = hf.RawFilePos + hf.SectorOffsets[hf.dwSectorCount];
    if(hf.pPatchInfo !is null)
        RawFilePos += hf.pPatchInfo.dwLength;
    if(!FileStream_Write(ha.pStream, &RawFilePos, pbCompressed[0 .. dwCompressedSize]))
        nError = GetLastError();

    // Not necessary, as the sector checksums
    // are going to be freed when this is done.
//  BSWAP_ARRAY32_UNSIGNED(hf.SectorChksums, dwCrcSize);

    // Store the sector CRCs 
    hf.SectorOffsets[hf.dwSectorCount + 1] = hf.SectorOffsets[hf.dwSectorCount] + cast(uint)dwCompressedSize;
    pFileEntry.dwCmpSize += dwCompressedSize;
    return nError;
}

int WriteMemDataMD5(
    TFileStream pStream,
    ulong RawDataOffs,
    ubyte[] pbRawData,
    size_t dwChunkSize,
    out size_t pcbTotalSize)
{
    ubyte[] md5_array;
    ubyte* md5;
    size_t dwBytesRemaining = pbRawData.length;
    int nError = ERROR_SUCCESS;

    // Allocate buffer for array of MD5
    md5_array = AllocateMd5Buffer(pbRawData.length, dwChunkSize);
    md5 = md5_array.ptr;
    
    // save length
    size_t dwRawDataSize = pbRawData.length;
    
    // For every file chunk, calculate MD5
    while(dwBytesRemaining != 0)
    {
        // Get the remaining number of bytes to read
        dwChunkSize = STORMLIB_MIN(dwBytesRemaining, dwChunkSize);

        // Calculate MD5
        CalculateDataBlockHash(pbRawData[0 .. dwChunkSize], md5);
        md5 += MD5_DIGEST_SIZE;

        // Move offset and size
        dwBytesRemaining -= dwChunkSize;
        pbRawData = pbRawData[dwChunkSize .. $];
    }

    // Write the array of MD5's to the file
    RawDataOffs += dwRawDataSize;
    if(!FileStream_Write(pStream, &RawDataOffs, md5_array))
        nError = GetLastError();

    // Give the caller the size of the MD5 array
    pcbTotalSize = dwRawDataSize + md5_array.length;

    return nError;
}

//// Writes the MD5 for each chunk of the raw file data
int WriteMpqDataMD5(
    TFileStream pStream,
    ulong RawDataOffs,
    size_t dwRawDataSize,
    size_t dwChunkSize)
{
    ubyte[] md5_array;
    ubyte* md5;
    ubyte[] pbFileChunk;
    
    size_t dwToRead = dwRawDataSize;
    int nError = ERROR_SUCCESS;

    // Allocate buffer for array of MD5
    md5_array = AllocateMd5Buffer(dwRawDataSize, dwChunkSize);
    md5 = md5_array.ptr;
    
    // Allocate space for file chunk
    pbFileChunk = new ubyte[dwChunkSize];

    // For every file chunk, calculate MD5
    while(dwRawDataSize != 0)
    {
        // Get the remaining number of bytes to read
        dwToRead = STORMLIB_MIN(dwRawDataSize, dwChunkSize);

        // Read the chunk
        if(!FileStream_Read(pStream, &RawDataOffs, pbFileChunk[0 .. dwToRead]))
        {
            nError = GetLastError();
            break;
        }

        // Calculate MD5
        CalculateDataBlockHash(pbFileChunk[0 .. dwToRead], md5);
        md5 += MD5_DIGEST_SIZE;

        // Move offset and size
        RawDataOffs += dwToRead;
        dwRawDataSize -= dwToRead;
    }

    // Write the array of MD5's to the file
    if(nError == ERROR_SUCCESS)
    {
        if(!FileStream_Write(pStream, null, md5_array))
            nError = GetLastError();
    }

    return nError;
}

// Frees the structure for MPQ file
void FreeFileHandle(ref TMPQFile hf)
{
    if(hf !is null)
    {
        // If we have patch file attached to this one, free it first
        if(hf.hfPatch !is null)
            FreeFileHandle(hf.hfPatch);

        // Then free all buffers allocated in the file structure
        if(hf.pPatchHeader !is null)
            hf.pPatchHeader = null;
        if(hf.pbFileData !is null)
            hf.pbFileData = null;
        if(hf.pPatchInfo !is null)
            hf.pPatchInfo = null;
        if(hf.SectorOffsets !is null)
            hf.SectorOffsets = null;
        if(hf.SectorChksums !is null)
            hf.SectorChksums = null;
        if(hf.pbFileSector !is null)
            hf.pbFileSector = null;
        if(hf.pStream !is null)
            FileStream_Close(hf.pStream);
        hf = null;
    }
}

//// Frees the MPQ archive
void FreeArchiveHandle(ref TMPQArchive ha)
{
    if(ha !is null)
    {
        // First of all, free the patch archive, if any
        if(ha.haPatch !is null)
            FreeArchiveHandle(ha.haPatch);

        // Close the file stream
        FileStream_Close(ha.pStream);
        ha.pStream = null;

        // Free the file names from the file table
        if(ha.pFileTable !is null)
        {
            for(uint i = 0; i < ha.dwFileTableSize; i++)
            {
                ha.pFileTable[i].szFileName = null;
            }

            // Then free all buffers allocated in the archive structure
            ha.pFileTable = null;
        }

        if(ha.pHashTable !is null)
            ha.pHashTable = null;
        if(ha.pHetTable !is null)
            FreeHetTable(ha.pHetTable);
        ha = null;
    }
}

bool IsInternalMpqFileName(string szFileName)
{
    if(szFileName !is null && szFileName.length != 0 && szFileName[0] == '(')
    {
        if(!szFileName.find(LISTFILE_NAME).empty ||
           !szFileName.find(ATTRIBUTES_NAME).empty ||
           !szFileName.find(SIGNATURE_NAME).empty)
        {
            return true;
        }
    }

    return false;
}

// Verifies if the file name is a pseudo-name
bool IsPseudoFileName(string szFileName, out size_t pdwFileIndex)
{
    size_t dwFileIndex = 0;

    if(szFileName !is null && szFileName.length != 0)
    {
        // Must be "File########.ext"
        if(countUntil(szFileName, "File") == 0)
        {
            // Check 8 digits
            for(int i = 4; i < 4+8; i++)
            {
                if(szFileName[i] < '0' || szFileName[i] > '9')
                    return false;
                dwFileIndex = (dwFileIndex * 10) + (szFileName[i] - '0');
            }

            // An extension must follow
            if(szFileName[12] == '.')
            {
                pdwFileIndex = dwFileIndex;
                return true;
            }
        }
    }

    // Not a pseudo-name
    return false;
}