/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.constants;

enum StormLibCopyright = "StormLib v " ~ STORMLIB_VERSION_STRING ~ " Copyright Ladislav Zezula 1998-2014";

/// Current version of StormLib (9.0)
enum STORMLIB_VERSION = 0x0900;
/// String version of StormLib version
enum STORMLIB_VERSION_STRING = "9.00";

/// MPQ archive header ID ('MPQ\x1A')
enum ID_MPQ = 0x1A51504D;
/// MPQ userdata entry ('MPQ\x1B')
enum ID_MPQ_USERDATA = 0x1B51504D;  
/// MPK archive header ID ('MPK\x1A')
enum ID_MPK = 0x1A4B504D;  

/// TODO: Move to exceptions
/// Not a MPQ file, but an AVI file.
enum ERROR_AVI_FILE                 = 10000;  
/// Returned by SFileReadFile when can't find file key
enum ERROR_UNKNOWN_FILE_KEY         = 10001; 
/// Returned by SFileReadFile when sector CRC doesn't match
enum ERROR_CHECKSUM_ERROR           = 10002;  
/// The given operation is not allowed on internal file
enum ERROR_INTERNAL_FILE            = 10003;  
/// The file is present as incremental patch file, but base file is missing
enum ERROR_BASE_FILE_MISSING        = 10004;  
/// The file was marked as "deleted" in the MPQ
enum ERROR_MARKED_FOR_DELETE        = 10005;  
/// The required file part is missing
enum ERROR_FILE_INCOMPLETE          = 10006;  
/// A name of at least one file is unknown
enum ERROR_UNKNOWN_FILE_NAMES       = 10007;  

// Values for SFileCreateArchive
/// Block index for deleted entry in the hash table
enum HASH_ENTRY_DELETED        = 0xFFFFFFFE;  
/// Block index for free entry in the hash table
enum HASH_ENTRY_FREE           = 0xFFFFFFFF;  

/// NameHash1 value for a deleted entry
enum HET_ENTRY_DELETED               = 0x80;  
/// NameHash1 value for free entry
enum HET_ENTRY_FREE                  = 0x00;  
/// Size of LibTomCrypt's hash_state structure
enum HASH_STATE_SIZE                 = 0x60;  
/// Maximum length of the patch prefix
enum MPQ_PATCH_PREFIX_LEN            = 0x20; 

// Values for SFileOpenArchive
/// Open the archive on HDD
enum SFILE_OPEN_HARD_DISK_FILE          = 2; 
/// Open the archive only if it is on CDROM
enum SFILE_OPEN_CDROM_FILE              = 3;  

// Values for SFileOpenFile
/// Open the file from the MPQ archive
enum SFILE_OPEN_FROM_MPQ       = 0x00000000;
/// Reserved for StormLib internal use
enum SFILE_OPEN_BASE_FILE      = 0xFFFFFFFD;
/// Reserved for StormLib internal use
enum SFILE_OPEN_ANY_LOCALE     = 0xFFFFFFFE;
/// Open a local file
enum SFILE_OPEN_LOCAL_FILE     = 0xFFFFFFFF;

// Flags for TMPQArchive::dwFlags
/// If set, the MPQ has been open for read-only access
enum MPQ_FLAG_READ_ONLY             = 0x00000001; 
/// If set, the MPQ tables have been changed
enum MPQ_FLAG_CHANGED               = 0x00000002; 
/// Malformed data structure detected (W3M map protectors)
enum MPQ_FLAG_MALFORMED             = 0x00000004; 
/// Checking sector CRC when reading files
enum MPQ_FLAG_CHECK_SECTOR_CRC      = 0x00000008; 
/// If set, it means that the (listfile) has been invalidated
enum MPQ_FLAG_LISTFILE_INVALID      = 0x00000020; 
/// If set, it means that the (attributes) has been invalidated
enum MPQ_FLAG_ATTRIBUTES_INVALID    = 0x00000040; 
/// If set, we are saving MPQ internal files and MPQ tables
enum MPQ_FLAG_SAVING_TABLES         = 0x00000080; 

// Values for TMPQArchive::dwSubType
/// The file is a MPQ file (Blizzard games)
enum MPQ_SUBTYPE_MPQ           = 0x00000000;  
/// The file is a SQP file (War of the Immortals)
enum MPQ_SUBTYPE_SQP           = 0x00000001;  
/// The file is a MPK file (Longwu Online)
enum MPQ_SUBTYPE_MPK           = 0x00000002;  

// Return value for SFileGetFileSize and SFileSetFilePointer
enum SFILE_INVALID_SIZE        = 0xFFFFFFFF;
enum SFILE_INVALID_POS         = 0xFFFFFFFF;
enum SFILE_INVALID_ATTRIBUTES  = 0xFFFFFFFF;

// Flags for SFileAddFile
/// Implode method (By PKWARE Data Compression Library)
enum MPQ_FILE_IMPLODE          = 0x00000100;  
/// Compress methods (By multiple methods)
enum MPQ_FILE_COMPRESS         = 0x00000200;  
/// Indicates whether file is encrypted
enum MPQ_FILE_ENCRYPTED        = 0x00010000;  
/// File decryption key has to be fixed 
enum MPQ_FILE_FIX_KEY          = 0x00020000;  
/// The file is a patch file. Raw file data begin with TPatchInfo structure
enum MPQ_FILE_PATCH_FILE       = 0x00100000;  
/// File is stored as a single unit, rather than split into sectors (Thx, Quantam)
enum MPQ_FILE_SINGLE_UNIT      = 0x01000000;  
/// File is a deletion marker. Used in MPQ patches, indicating that the file no longer exists.
enum MPQ_FILE_DELETE_MARKER    = 0x02000000;  
/// File has checksums for each sector.
/// Ignored if file is not compressed or imploded.
enum MPQ_FILE_SECTOR_CRC       = 0x04000000;  
                                                
/// Mask for a file being compressed
enum MPQ_FILE_COMPRESS_MASK    = 0x0000FF00;  
/// Set if file exists, reset when the file was deleted
enum MPQ_FILE_EXISTS           = 0x80000000;  
/// Replace when the file exist (SFileAddFile)
enum MPQ_FILE_REPLACEEXISTING  = 0x80000000;  

enum MPQ_FILE_VALID_FLAGS    = (MPQ_FILE_IMPLODE       |  
                                MPQ_FILE_COMPRESS      |  
                                MPQ_FILE_ENCRYPTED     |  
                                MPQ_FILE_FIX_KEY       |  
                                MPQ_FILE_PATCH_FILE    |  
                                MPQ_FILE_SINGLE_UNIT   |  
                                MPQ_FILE_DELETE_MARKER |  
                                MPQ_FILE_SECTOR_CRC    |  
                                MPQ_FILE_EXISTS);

// Compression types for multiple compressions
/// Huffmann compression (used on WAVE files only)
enum MPQ_COMPRESSION_HUFFMANN       = 0x01;  
/// ZLIB compression
enum MPQ_COMPRESSION_ZLIB           = 0x02;  
/// PKWARE DCL compression
enum MPQ_COMPRESSION_PKWARE         = 0x08; 
/// BZIP2 compression (added in Warcraft III) 
enum MPQ_COMPRESSION_BZIP2          = 0x10;
/// Sparse compression (added in Starcraft 2)
enum MPQ_COMPRESSION_SPARSE         = 0x20;
/// IMA ADPCM compression (mono)
enum MPQ_COMPRESSION_ADPCM_MONO     = 0x40; 
/// IMA ADPCM compression (stereo)
enum MPQ_COMPRESSION_ADPCM_STEREO   = 0x80;  
/// LZMA compression. Added in Starcraft 2. This value is NOT a combination of flags.
enum MPQ_COMPRESSION_LZMA           = 0x12;  
/// Same compression
enum MPQ_COMPRESSION_NEXT_SAME      = 0xFFFFFFFF;

// Constants for SFileAddWave
/// Best quality, the worst compression
enum MPQ_WAVE_QUALITY_HIGH              = 0; 
/// Medium quality, medium compression
enum MPQ_WAVE_QUALITY_MEDIUM            = 1; 
/// Low quality, the best compression
enum MPQ_WAVE_QUALITY_LOW               = 2; 

// Signatures for HET and BET table
/// 'HET\x1a'
enum HET_TABLE_SIGNATURE       = 0x1A544548; 
/// 'BET\x1a'
enum BET_TABLE_SIGNATURE       = 0x1A544542; 

// Decryption keys for MPQ tables
/// Obtained by HashString("(hash table)", MPQ_HASH_FILE_KEY)
enum MPQ_KEY_HASH_TABLE        = 0xC3AF3770; 
/// Obtained by HashString("(block table)", MPQ_HASH_FILE_KEY)
enum MPQ_KEY_BLOCK_TABLE       = 0xEC83B3A3; 

/// Name of internal listfile
enum LISTFILE_NAME             = "(listfile)"; 
/// Name of internal signature
enum SIGNATURE_NAME           = "(signature)"; 
/// Name of internal attributes file
enum ATTRIBUTES_NAME         = "(attributes)"; 
enum PATCH_METADATA_NAME  = "(patch_metadata)";

/// Up to The Burning Crusade
enum MPQ_FORMAT_VERSION_1               = 0; 
/// The Burning Crusade and newer
enum MPQ_FORMAT_VERSION_2               = 1; 
/// WoW Cataclysm Beta
enum MPQ_FORMAT_VERSION_3               = 2; 
/// WoW Cataclysm and newer
enum MPQ_FORMAT_VERSION_4               = 3; 

// Flags for MPQ attributes
/// The "(attributes)" contains CRC32 for each file
enum MPQ_ATTRIBUTE_CRC32       = 0x00000001;  
/// The "(attributes)" contains file time for each file
enum MPQ_ATTRIBUTE_FILETIME    = 0x00000002;  
/// The "(attributes)" contains MD5 for each file
enum MPQ_ATTRIBUTE_MD5         = 0x00000004;  
/// The "(attributes)" contains a patch bit for each file
enum MPQ_ATTRIBUTE_PATCH_BIT   = 0x00000008;  
/// Summary mask
enum MPQ_ATTRIBUTE_ALL         = 0x0000000F;  

/// (attributes) format version 1.00
enum MPQ_ATTRIBUTES_V1                = 100;  

// Flags for SFileOpenArchive
/// Base data source is a file
enum BASE_PROVIDER_FILE        = 0x00000000;  
/// Base data source is memory-mapped file
enum BASE_PROVIDER_MAP         = 0x00000001;  
/// Base data source is a file on web server
enum BASE_PROVIDER_HTTP        = 0x00000002;  
/// Mask for base provider value
enum BASE_PROVIDER_MASK        = 0x0000000F;  

/// Stream is linear with no offset mapping
enum STREAM_PROVIDER_FLAT      = 0x00000000;  
/// Stream is partial file (.part)
enum STREAM_PROVIDER_PARTIAL   = 0x00000010;  
/// Stream is an encrypted MPQ
enum STREAM_PROVIDER_MPQE      = 0x00000020;  
/// 0x4000 per block, text MD5 after each block, max 0x2000 blocks per file
enum STREAM_PROVIDER_BLOCK4    = 0x00000030;  
/// Mask for stream provider value
enum STREAM_PROVIDER_MASK      = 0x000000F0;  

/// Stream is read only
enum STREAM_FLAG_READ_ONLY     = 0x00000100;  
/// Allow write sharing when open for write
enum STREAM_FLAG_WRITE_SHARE   = 0x00000200;  
/// If the file has a file bitmap, load it and use it
enum STREAM_FLAG_USE_BITMAP    = 0x00000400;  
/// Mask for stream options
enum STREAM_OPTIONS_MASK       = 0x0000FF00;  

/// Mask to get stream providers
enum STREAM_PROVIDERS_MASK     = 0x000000FF; 
/// Mask for all stream flags (providers+options)
enum STREAM_FLAGS_MASK         = 0x0000FFFF; 

/// Don't load the internal listfile
enum MPQ_OPEN_NO_LISTFILE      = 0x00010000; 
/// Don't open the attributes
enum MPQ_OPEN_NO_ATTRIBUTES    = 0x00020000; 
/// Don't search for the MPQ header past the begin of the file
enum MPQ_OPEN_NO_HEADER_SEARCH = 0x00040000; 
/// Always open the archive as MPQ v 1.00, ignore the "wFormatVersion" variable in the header
enum MPQ_OPEN_FORCE_MPQ_V1     = 0x00080000; 
/// On files with MPQ_FILE_SECTOR_CRC, the CRC will be checked when reading file
enum MPQ_OPEN_CHECK_SECTOR_CRC = 0x00100000; 
enum MPQ_OPEN_READ_ONLY        = STREAM_FLAG_READ_ONLY;

// Flags for SFileCreateArchive
/// Also add the (listfile) file
enum MPQ_CREATE_LISTFILE       = 0x00100000; 
/// Also add the (attributes) file
enum MPQ_CREATE_ATTRIBUTES     = 0x00200000; 
/// Creates archive of version 1 (size up to 4GB)
enum MPQ_CREATE_ARCHIVE_V1     = 0x00000000; 
/// Creates archive of version 2 (larger than 4 GB)
enum MPQ_CREATE_ARCHIVE_V2     = 0x01000000; 
/// Creates archive of version 3
enum MPQ_CREATE_ARCHIVE_V3     = 0x02000000; 
/// Creates archive of version 4
enum MPQ_CREATE_ARCHIVE_V4     = 0x03000000; 
/// Mask for archive version
enum MPQ_CREATE_ARCHIVE_VMASK  = 0x0F000000; 

/// (MPQ_CREATE_ARCHIVE_V4 >> FLAGS_TO_FORMAT_SHIFT) => MPQ_FORMAT_VERSION_4
enum FLAGS_TO_FORMAT_SHIFT             = 24; 

// Flags for SFileVerifyFile
/// Verify sector checksum for the file, if available
enum SFILE_VERIFY_SECTOR_CRC   = 0x00000001; 
/// Verify file CRC, if available
enum SFILE_VERIFY_FILE_CRC     = 0x00000002; 
/// Verify file MD5, if available
enum SFILE_VERIFY_FILE_MD5     = 0x00000004; 
/// Verify raw file MD5, if available
enum SFILE_VERIFY_RAW_MD5      = 0x00000008; 
/// Verify every checksum possible
enum SFILE_VERIFY_ALL          = 0x0000000F; 

// Return values for SFileVerifyFile
/// Failed to open the file
enum VERIFY_OPEN_ERROR             = 0x0001; 
/// Failed to read all data from the file
enum VERIFY_READ_ERROR             = 0x0002; 
/// File has sector CRC
enum VERIFY_FILE_HAS_SECTOR_CRC    = 0x0004; 
/// Sector CRC check failed
enum VERIFY_FILE_SECTOR_CRC_ERROR  = 0x0008; 
/// File has CRC32
enum VERIFY_FILE_HAS_CHECKSUM      = 0x0010; 
/// CRC32 check failed
enum VERIFY_FILE_CHECKSUM_ERROR    = 0x0020; 
/// File has data MD5
enum VERIFY_FILE_HAS_MD5           = 0x0040; 
/// MD5 check failed
enum VERIFY_FILE_MD5_ERROR         = 0x0080; 
/// File has raw data MD5
enum VERIFY_FILE_HAS_RAW_MD5       = 0x0100; 
/// Raw MD5 check failed
enum VERIFY_FILE_RAW_MD5_ERROR     = 0x0200; 
enum VERIFY_FILE_ERROR_MASK     = (VERIFY_OPEN_ERROR | VERIFY_READ_ERROR | VERIFY_FILE_SECTOR_CRC_ERROR | VERIFY_FILE_CHECKSUM_ERROR | VERIFY_FILE_MD5_ERROR | VERIFY_FILE_RAW_MD5_ERROR);

// Flags for SFileVerifyRawData (for MPQs version 4.0 or higher)
/// Verify raw MPQ header
enum SFILE_VERIFY_MPQ_HEADER       = 0x0001; 
/// Verify raw data of the HET table
enum SFILE_VERIFY_HET_TABLE        = 0x0002; 
/// Verify raw data of the BET table
enum SFILE_VERIFY_BET_TABLE        = 0x0003; 
/// Verify raw data of the hash table
enum SFILE_VERIFY_HASH_TABLE       = 0x0004; 
/// Verify raw data of the block table
enum SFILE_VERIFY_BLOCK_TABLE      = 0x0005; 
/// Verify raw data of the hi-block table
enum SFILE_VERIFY_HIBLOCK_TABLE    = 0x0006; 
/// Verify raw data of a file
enum SFILE_VERIFY_FILE             = 0x0007; 

// Signature types
/// The archive has no signature in it
enum SIGNATURE_TYPE_NONE           = 0x0000; 
/// The archive has weak signature
enum SIGNATURE_TYPE_WEAK           = 0x0001; 
/// The archive has strong signature
enum SIGNATURE_TYPE_STRONG         = 0x0002; 

// Return values for SFileVerifyArchive
/// There is no signature in the MPQ
enum ERROR_NO_SIGNATURE                 = 0; 
/// There was an error during verifying signature (like no memory)
enum ERROR_VERIFY_FAILED                = 1; 
/// There is a weak signature and sign check passed
enum ERROR_WEAK_SIGNATURE_OK            = 2; 
/// There is a weak signature but sign check failed
enum ERROR_WEAK_SIGNATURE_ERROR         = 3; 
/// There is a strong signature and sign check passed
enum ERROR_STRONG_SIGNATURE_OK          = 4; 
/// There is a strong signature but sign check failed
enum ERROR_STRONG_SIGNATURE_ERROR       = 5; 
                                           
enum MD5_DIGEST_SIZE                   = 0x10;
enum SHA1_DIGEST_SIZE                  = 0x14;  // 160 bits
enum LANG_NEUTRAL                      = 0x00;  // Neutral locale

// Prevent problems with CRT "min" and "max" functions,
// as they are not defined on all platforms
T STORMLIB_MIN(T)(T a, T b)
{
    return (a < b) ? a : b;
}

T STORMLIB_MAX(T)(T a, T b) 
{
    return (a > b) ? a : b;
}

/// Macro for building 64-bit file offset from two 32-bit
ulong MAKE_OFFSET64(uint hi, uint lo)
{
    return (cast(ulong)hi << 32) | cast(ulong)lo;
}