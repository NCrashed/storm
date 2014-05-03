/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Structures related to MPQ format
*
*   Note: All structures in this header file are supposed to remain private
*   to StormLib. The structures may (and will) change over time, as the MPQ
*   file format evolves. Programmers directly using these structures need to
*   be aware of this. And the last, but not least, NEVER do any modifications
*   to those structures directly, always use SFile* functions.
*/
module storm.mpq;

import storm.constants;

enum MPQ_HEADER_SIZE_V1  = 0x20;
enum MPQ_HEADER_SIZE_V2  = 0x2C;
enum MPQ_HEADER_SIZE_V3  = 0x44;
enum MPQ_HEADER_SIZE_V4  = 0xD0;
enum MPQ_HEADER_DWORDS   = MPQ_HEADER_SIZE_V4 / 0x04;

struct TMPQuserData
{
    /// The ID_MPQ_USERDATA ('MPQ\x1B') signature
    uint dwID;

    /// Maximum size of the user data
    uint cbUserDataSize;

    /// Offset of the MPQ header, relative to the begin of this header
    uint dwHeaderOffs;

    /// Appears to be size of user data header (Starcraft II maps)
    uint cbUserDataHeader;
}

/**
*   MPQ file header
*   
*   We have to make sure that the header is packed OK.
*   Reason: A 64-bit integer at the beginning of 3.0 part,
*   which is offset 0x2C
*/
align(1) struct TMPQHeader
{
    /// The ID_MPQ ('MPQ\x1A') signature
    uint dwID;

    /// Size of the archive header
    uint dwHeaderSize;

    /**
    *   32-bit size of MPQ archive
    *
    *   This field is deprecated in the Burning Crusade MoPaQ format, and the size of the archive
    *   is calculated as the size from the beginning of the archive to the end of the hash table,
    *   block table, or hi-block table (whichever is largest).
    */
    uint dwArchiveSize;

    /**
    *   0 = Format 1 (up to The Burning Crusade)
    *   1 = Format 2 (The Burning Crusade and newer)
    *   2 = Format 3 (WoW - Cataclysm beta or newer)
    *   3 = Format 4 (WoW - Cataclysm beta or newer)
    */
    ushort wFormatVersion;

    /**
    *   Power of two exponent specifying the number of 512-byte disk sectors in each file sector
    *   in the archive. The size of each file sector in the archive is 512 * 2 ^ wSectorSize.
    */
    ushort wSectorSize;

    /// Offset to the beginning of the hash table, relative to the beginning of the archive.
    uint dwHashTablePos;
    
    /// Offset to the beginning of the block table, relative to the beginning of the archive.
    uint dwBlockTablePos;
    
    /**
    *   Number of entries in the hash table. Must be a power of two, and must be less than 2^16 for
    *   the original MoPaQ format, or less than 2^20 for the Burning Crusade format.
    */
    uint dwHashTableSize;
    
    /// Number of entries in the block table
    uint dwBlockTableSize;

    //-- MPQ HEADER v 2 -------------------------------------------

    /// Offset to the beginning of array of 16-bit high parts of file offsets.
    ulong HiBlockTablePos64;

    /// High 16 bits of the hash table offset for large archives.
    ushort wHashTablePosHi;

    /// High 16 bits of the block table offset for large archives.
    ushort wBlockTablePosHi;

    //-- MPQ HEADER v 3 -------------------------------------------

    /// 64-bit version of the archive size
    ulong ArchiveSize64;

    /// 64-bit position of the BET table
    ulong BetTablePos64;

    /// 64-bit position of the HET table
    ulong HetTablePos64;

    //-- MPQ HEADER v 4 -------------------------------------------

    /// Compressed size of the hash table
    ulong HashTableSize64;

    /// Compressed size of the block table
    ulong BlockTableSize64;

    /// Compressed size of the hi-block table
    ulong HiBlockTableSize64;

    /// Compressed size of the HET block
    ulong HetTableSize64;

    /// Compressed size of the BET block
    ulong BetTableSize64;

    /**
    *   Size of raw data chunk to calculate MD5.
    *   MD5 of each data chunk follows the raw file data.
    */
    uint dwRawChunkSize;                                 

    // MD5 of MPQ tables
    /// MD5 of the block table before decryption
    ubyte[MD5_DIGEST_SIZE] MD5_BlockTable;      
    /// MD5 of the hash table before decryption
    ubyte[MD5_DIGEST_SIZE] MD5_HashTable;       
    /// MD5 of the hi-block table
    ubyte[MD5_DIGEST_SIZE] MD5_HiBlockTable;    
    /// MD5 of the BET table before decryption
    ubyte[MD5_DIGEST_SIZE] MD5_BetTable;        
    /// MD5 of the HET table before decryption
    ubyte[MD5_DIGEST_SIZE] MD5_HetTable;        
    /// MD5 of the MPQ header from signature to (including) MD5_HetTable
    ubyte[MD5_DIGEST_SIZE] MD5_MpqHeader;       
}

/// Hash table entry. All files in the archive are searched by their hashes.
struct TMPQHash
{
    /// The hash of the file path, using method A.
    uint dwName1;
    
    /// The hash of the file path, using method B.
    uint dwName2;

    version(LittleEndian)
    {
        /**
        *   The language of the file. This is a Windows LANGID data type, and uses the same values.
        *   0 indicates the default language (American English), or that the file is language-neutral.
        */
        ushort lcLocale;
    
        /**
        *   The platform the file is used for. 0 indicates the default platform.
        *   No other values have been observed.
        *   Note: wPlatform is actually just BYTE, but since it has never been used, we don't care.
        */
        ushort wPlatform;
    }
    else
    {
        ushort wPlatform;
        ushort lcLocale;
    }

    /**
    *   If the hash table entry is valid, this is the index into the block table of the file.
    *   Otherwise, one of the following two values:
    *    - FFFFFFFFh: Hash table entry is empty, and has always been empty.
    *                 Terminates searches for a given file.
    *    - FFFFFFFEh: Hash table entry is empty, but was valid at some point (a deleted file).
    *                 Does not terminate searches for a given file.
    */
    uint dwBlockIndex;
}