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
import storm.bitarray;
import storm.miscs;

enum MPQ_HEADER_SIZE_V1  = 0x20;
enum MPQ_HEADER_SIZE_V2  = 0x2C;
enum MPQ_HEADER_SIZE_V3  = 0x44;
enum MPQ_HEADER_SIZE_V4  = 0xD0;
enum MPQ_HEADER_DWORDS   = MPQ_HEADER_SIZE_V4 / 0x04;

struct TMPQUserData
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

/// Structure for parsed HET table
struct TMPQHetTable
{
    /// Bit array of FileIndex values
    BitArray   pBetIndexes;                    
    /// Array of NameHash1 values (NameHash1 = upper 8 bits of FileName hash)
    ubyte[]    pNameHashes;                     
    /// AND mask used for calculating file name hash
    ulong      AndMask64;                       
    /// OR mask used for setting the highest bit of the file name hash
    ulong      OrMask64;                        

    /// Number of occupied entries in the HET table
    uint      dwEntryCount;                    
    /// Number of entries in both NameHash and FileIndex table
    uint      dwTotalCount;                    
    /// Size of the name hash entry (in bits)
    uint      dwNameHashBitSize;               
    /// Total size of one entry in pBetIndexes (in bits)
    uint      dwIndexSizeTotal;                
    /// Extra bits in the entry in pBetIndexes
    uint      dwIndexSizeExtra;                
    /// Effective size of one entry in pBetIndexes (in bits)
    uint      dwIndexSize;                     
}

/// Structure for parsed BET table
struct TMPQBetTable
{
    /// Array of NameHash2 entries (lower 24 bits of FileName hash)
    BitArray pNameHashes;                    
    /// Bit-based file table
    BitArray pFileTable;                     
    /// Array of file flags
    uint[] pFileFlags;                         

    /// Size of one table entry, in bits
    uint dwTableEntrySize;                     
    /// Bit index of the file position in the table entry
    uint dwBitIndex_FilePos;                   
    /// Bit index of the file size in the table entry
    uint dwBitIndex_FileSize;                  
    /// Bit index of the compressed size in the table entry
    uint dwBitIndex_CmpSize;                   
    /// Bit index of the flag index in the table entry
    uint dwBitIndex_FlagIndex;                 
    /// Bit index of ??? in the table entry
    uint dwBitIndex_Unknown;                   
    /// Size of file offset (in bits) within table entry
    uint dwBitCount_FilePos;                   
    /// Size of file size (in bits) within table entry
    uint dwBitCount_FileSize;                  
    /// Size of compressed file size (in bits) within table entry
    uint dwBitCount_CmpSize;                   
    /// Size of flag index (in bits) within table entry
    uint dwBitCount_FlagIndex;                 
    /// Size of ??? (in bits) within table entry
    uint dwBitCount_Unknown;                   
    /// Total size of the NameHash2
    uint dwBitTotal_NameHash2;                 
    /// Extra bits in the NameHash2
    uint dwBitExtra_NameHash2;                 
    /// Effective size of the NameHash2
    uint dwBitCount_NameHash2;                 
    /// Number of entries
    uint dwEntryCount;                         
    /// Number of fil flags in pFileFlags
    uint dwFlagCount;                          
}

/// Archive handle structure
struct TMPQArchive
{
    /// Open stream for the MPQ
    TFileStream* pStream;                     

    /// Position of user data (relative to the begin of the file)
    ulong      UserDataPos;                 
    /// MPQ header offset (relative to the begin of the file)
    ulong      MpqPos;                      

    /// Pointer to patch archive, if any
    TMPQArchive* haPatch;              
    /// Pointer to base ("previous version") archive, if any
    TMPQArchive* haBase;               
    /// Prefix for file names in patch MPQs
    char[MPQ_PATCH_PREFIX_LEN] szPatchPrefix;   
    /// Length of the patch prefix, in characters
    size_t         cchPatchPrefix;              

    /// MPQ user data (NULL if not present in the file)
    TMPQUserData * pUserData;                   
    /// MPQ file header
    TMPQHeader   * pHeader;                     
    /// Hash table
    TMPQHash     * pHashTable;                  
    /// HET table
    TMPQHetTable * pHetTable;                   
    /// File table
    TFileEntry   * pFileTable;                  
    /// Hashing function that will convert the file name into hash
    HASH_STRING    pfnHashString;               
    
    /// MPQ user data. Valid only when ID_MPQ_USERDATA has been found
    TMPQUserData   UserData;                    
    /// Storage for MPQ header
    uint[MPQ_HEADER_DWORDS] HeaderData;  

    uint          dwHETBlockSize;
    uint          dwBETBlockSize;
    /// Maximum number of files in the MPQ. Also total size of the file table.
    uint          dwMaxFileCount;              
    /// Current size of the file table, e.g. index of the entry past the last occupied one
    uint          dwFileTableSize;             
    /// Number of entries reserved for internal MPQ files (listfile, attributes)
    uint          dwReservedFiles;             
    /// Default size of one file sector
    uint          dwSectorSize;                
    /// Flags for (listfile)
    uint          dwFileFlags1;                
    /// Flags for (attributes)
    uint          dwFileFlags2;                
    /// Flags for the (attributes) file, see MPQ_ATTRIBUTE_XXX
    uint          dwAttrFlags;                 
    /// See MPQ_FLAG_XXXXX
    uint          dwFlags;                     
    /// See MPQ_SUBTYPE_XXX
    uint          dwSubType;                   

    /// Callback function for adding files
    SFILE_ADDFILE_CALLBACK pfnAddFileCB;        
    /// User data thats passed to the callback
    void         * pvAddFileUserData;           

    /// Callback function for compacting the archive
    SFILE_COMPACT_CALLBACK pfnCompactCB;
    /// Amount of bytes that have been processed during a particular compact call
    ulong      CompactBytesProcessed;       
    /// Total amount of bytes to be compacted
    ulong      CompactTotalBytes;           
    /// User data thats passed to the callback
    void         * pvCompactUserData;           
}                                     

/// File handle structure
struct TMPQFile
{
    /// File stream. Only used on local files
    TFileStream  * pStream;                     
    /// Archive handle
    TMPQArchive  * ha;                          
    /// File entry for the file
    TFileEntry   * pFileEntry;                 
    /// Decryption key 
    uint          dwFileKey;                   
    /// Current file position
    uint          dwFilePos;                
    /// Offset in MPQ archive (relative to file begin)   
    ulong      RawFilePos;                  
    /// Offset in MPQ archive (relative to MPQ header)
    ulong      MpqFilePos;                  
    /// 'FILE'
    uint          dwMagic;                     

    /// Pointer to opened patch file
    TMPQFile * hfPatch;                 
    /// Patch header. Only used if the file is a patch file
    TPatchHeader * pPatchHeader;                
    /// Loaded and patched file data. Only used if the file is a patch file
    ubyte[]       pbFileData;                 
    /// Size of loaded patched data 
    uint          cbFileData;                  

    /// Patch info block, preceding the sector table
    TPatchInfo   * pPatchInfo;                 
    /// Position of each file sector, relative to the begin of the file. Only for compressed files.
    uint[]        SectorOffsets;               
    /// Array of sector checksums (either ADLER32 or MD5) values for each file sector
    uint[]        SectorChksums;               
    /// Compression that will be used on the first file sector
    uint          dwCompression0;              
    /// Number of sectors in the file
    uint          dwSectorCount;               
    /// Size of patched file. Used when saving patch file to the MPQ
    uint          dwPatchedFileSize;           
    /// Size of data in the file (on patch files, this differs from file size in block table entry)
    uint          dwDataSize;                  

    /// Last loaded file sector. For single unit files, entire file content
    ubyte[]       pbFileSector;                
    /// File position of currently loaded file sector
    uint          dwSectorOffs;                
    /// Size of the file sector. For single unit files, this is equal to the file size
    uint          dwSectorSize;                

    /// Hash state for MD5. Used when saving file to MPQ
    ubyte[HASH_STATE_SIZE]  hctx;       
    /// CRC32 value, used when saving file to MPQ
    uint          dwCrc32;                     

    /// Result of the "Add File" operations
    int            nAddFileError;               

    /// If true, we already tried to load sector CRCs
    bool           bLoadedSectorCRCs;           
    /// If true, then SFileReadFile will check sector CRCs when reading the file
    bool           bCheckSectorCRCs;            
    /// If true, this handle has been created by SFileCreateFile
    bool           bIsWriteHandle;              
}

/// Structure for SFileFindFirstFile and SFileFindNextFile
struct SFILE_FIND_DATA
{
    /// Full name of the found file
    string cFileName;                 
    /// Plain name of the found file
    string szPlainName;                        
    /// Hash table index for the file 
    uint  dwHashIndex;                         
    /// Block table index for the file
    uint  dwBlockIndex;                        
    /// File size in bytes
    uint  dwFileSize;                          
    /// MPQ file flags
    uint  dwFileFlags;                         
    /// Compressed file size
    uint  dwCompSize;                          
    /// Low 32-bits of the file time (0 if not present)
    uint  dwFileTimeLo;                        
    /// High 32-bits of the file time (0 if not present)
    uint  dwFileTimeHi;                        
    /// Locale version
    LCID   lcLocale;                            

}

struct SFILE_CREATE_MPQ
{
    /// Size of this structure, in bytes
    uint cbSize;                               
    /// Version of the MPQ to be created
    uint dwMpqVersion;                         
    /// Reserved, must be NULL
    void *pvUserData;                          
    /// Reserved, must be 0 
    uint cbUserData;                           
    /// Stream flags for creating the MPQ
    uint dwStreamFlags;                        
    /// File flags for (listfile). 0 = default
    uint dwFileFlags1;                         
    /// File flags for (attributes). 0 = default
    uint dwFileFlags2;                         
    /// Flags for the (attributes) file. If 0, no attributes will be created
    uint dwAttrFlags;                          
    /// Sector size for compressed files
    uint dwSectorSize;                         
    /// Size of raw data chunk
    uint dwRawChunkSize;                       
    /// File limit for the MPQ
    uint dwMaxFileCount;                       

}