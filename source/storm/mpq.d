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
        *   Note: wPlatform is actually just ubyte, but since it has never been used, we don't care.
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

/// File description block contains informations about the file
struct TMPQBlock
{
    /// Offset of the beginning of the file, relative to the beginning of the archive.
    uint dwFilePos;
    
    /// Compressed file size
    uint dwCSize;
    
    /**
    *   Only valid if the block is a file; otherwise meaningless, and should be 0.
    *   If the file is compressed, this is the size of the uncompressed file data.
    */
    uint dwFSize;                      
    
    /// Flags for the file. See MPQ_FILE_XXXX constants
    uint dwFlags;                      
}

/// Patch file information, preceding the sector offset table
struct TPatchInfo
{
    /// Length of patch info header, in bytes
    uint dwLength;                             
    /// Flags. 0x80000000 = MD5 (?)
    uint dwFlags;                              
    /// Uncompressed size of the patch file
    uint dwDataSize;                           
    /// MD5 of the entire patch file after decompression
    ubyte[0x10] md5;                            

    // Followed by the sector table (variable length)
}

/// Header for PTCH files 
struct TPatchHeader
{
    //-- PATCH header -----------------------------------
    /// 'PTCH'
    uint dwSignature;                          
    /// Size of the entire patch (decompressed)
    uint dwSizeOfPatchData;                    
    /// Size of the file before patch
    uint dwSizeBeforePatch;                    
    /// Size of file after patch
    uint dwSizeAfterPatch;                     
    
    //-- MD5 block --------------------------------------
    /// 'MD5_'
    uint dwMD5;                                
    /// Size of the MD5 block, including the signature and size itself
    uint dwMd5BlockSize;                       
    /// MD5 of the original (unpatched) file
    ubyte[0x10] md5_before_patch;                
    /// MD5 of the patched file
    ubyte[0x10] md5_after_patch;                 

    //-- XFRM block -------------------------------------
    /// 'XFRM'
    uint dwXFRM;                               
    /// Size of the XFRM block, includes XFRM header and patch data
    uint dwXfrmBlockSize;                      
    /// Type of patch ('BSD0' or 'COPY')
    uint dwPatchType;                          

    // Followed by the patch data
}

enum SIZE_OF_XFRM_HEADER = 0x0C;

/**
*   This is the combined file entry for maintaining file list in the MPQ.
*   This structure is combined from block table, hi-block table,
*   (attributes) file and from (listfile).
*/
struct TFileEntry
{
    /// Jenkins hash of the file name. Only used when the MPQ has BET table.
    ulong FileNameHash;                     
    /// Position of the file content in the MPQ, relative to the MPQ header
    ulong ByteOffset;                       
    /// FileTime from the (attributes) file. 0 if not present.
    ulong FileTime;                         
    /// Index to the hash table. Only used when the MPQ has classic hash table
    uint     dwHashIndex;                      
    /// Decompressed size of the file
    uint     dwFileSize;                       
    /// Compressed size of the file (i.e., size of the file data in the MPQ)
    uint     dwCmpSize;                        
    /// File flags (from block table)
    uint     dwFlags;                          
    /// Locale ID for the file
    ushort    lcLocale;                         
    /// Platform ID for the file
    ushort    wPlatform;                       
    /// CRC32 from (attributes) file. 0 if not present. 
    uint     dwCrc32;                   
    /// File MD5 from the (attributes) file. 0 if not present.       
    ubyte[MD5_DIGEST_SIZE] md5;         
    /// File name. NULL if not known.
    string szFileName;                          
}

/// Common header for HET and BET tables
struct TMPQExtHeader
{
    /// 'HET\x1A' or 'BET\x1A'
    uint dwSignature;                          
    /// Version. Seems to be always 1
    uint dwVersion;                            
    /// Size of the contained table
    uint dwDataSize;                           

    // Followed by the table header
    // Followed by the table data

}

/// Structure for HET table header
struct TMPQHetHeader
{
    TMPQExtHeader ExtHdr;

    /// Size of the entire HET table, including HET_TABLE_HEADER (in bytes)
    uint dwTableSize;                      
    /// Number of occupied entries in the HET table
    uint dwEntryCount;                     
    /// Total number of entries in the HET table
    uint dwTotalCount;                     
    /// Size of the name hash entry (in bits)
    uint dwNameHashBitSize;                
    /// Total size of file index (in bits)
    uint dwIndexSizeTotal;                 
    /// Extra bits in the file index
    uint dwIndexSizeExtra;                 
    /// Effective size of the file index (in bits)
    uint dwIndexSize;                      
    /// Size of the block index subtable (in bytes)
    uint dwIndexTableSize;                 

}

/// Structure for BET table header
struct TMPQBetHeader
{
    TMPQExtHeader ExtHdr;

    /// Size of the entire BET table, including the header (in bytes)
    uint dwTableSize;                      
    /// Number of entries in the BET table. Must match HET_TABLE_HEADER::dwEntryCount
    uint dwEntryCount;                     
    uint dwUnknown08;
    /// Size of one table entry (in bits)
    uint dwTableEntrySize;                 
    /// Bit index of the file position (within the entry record)
    uint dwBitIndex_FilePos;               
    /// Bit index of the file size (within the entry record)
    uint dwBitIndex_FileSize;              
    /// Bit index of the compressed size (within the entry record)
    uint dwBitIndex_CmpSize;               
    /// Bit index of the flag index (within the entry record)
    uint dwBitIndex_FlagIndex;             
    /// Bit index of the ??? (within the entry record)
    uint dwBitIndex_Unknown;               
    /// Bit size of file position (in the entry record)
    uint dwBitCount_FilePos;               
    /// Bit size of file size (in the entry record)
    uint dwBitCount_FileSize;              
    /// Bit size of compressed file size (in the entry record)
    uint dwBitCount_CmpSize;               
    /// Bit size of flags index (in the entry record)
    uint dwBitCount_FlagIndex;             
    /// Bit size of ??? (in the entry record)
    uint dwBitCount_Unknown;               
    /// Total bit size of the NameHash2
    uint dwBitTotal_NameHash2;             
    /// Extra bits in the NameHash2
    uint dwBitExtra_NameHash2;             
    /// Effective size of NameHash2 (in bits)
    uint dwBitCount_NameHash2;             
    /// Size of NameHash2 table, in bytes
    uint dwNameHashArraySize;              
    /// Number of flags in the following array
    uint dwFlagCount;                      

}