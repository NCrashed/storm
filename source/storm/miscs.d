/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
/// Temporary file for small things that don't have any other place for now
module storm.miscs;

/// Hashing function
alias HASH_STRING = uint function(string fileName, uint hashType);

//-----------------------------------------------------------------------------
// File information classes for SFileGetFileInfo and SFileFreeFileInfo

enum SFileInfoClass
{
    // Info classes for archives
    /// Name of the archive file (TCHAR [])
    MpqFileName,                       
    /// Array of bits, each bit means availability of one block (BYTE [])
    MpqStreamBitmap,                   
    /// Offset of the user data header (ULONGLONG)
    MpqUserDataOffset,                 
    /// Raw (unfixed) user data header (TMPQUserData)
    MpqUserDataHeader,                 
    /// MPQ USer data, without the header (BYTE [])
    MpqUserData,                       
    /// Offset of the MPQ header (ULONGLONG)
    MpqHeaderOffset,                   
    /// Fixed size of the MPQ header
    MpqHeaderSize,                     
    /// Raw (unfixed) archive header (TMPQHeader)
    MpqHeader,                         
    /// Offset of the HET table, relative to MPQ header (ULONGLONG)
    MpqHetTableOffset,                 
    /// Compressed size of the HET table (ULONGLONG)
    MpqHetTableSize,                   
    /// HET table header (TMPQHetHeader)
    MpqHetHeader,                      
    /// HET table as pointer. Must be freed using SFileFreeFileInfo
    MpqHetTable,                       
    /// Offset of the BET table, relative to MPQ header (ULONGLONG)
    MpqBetTableOffset,                 
    /// Compressed size of the BET table (ULONGLONG)
    MpqBetTableSize,                   
    /// BET table header, followed by the flags (TMPQBetHeader + DWORD[])
    MpqBetHeader,                      
    /// BET table as pointer. Must be freed using SFileFreeFileInfo
    MpqBetTable,                       
    /// Hash table offset, relative to MPQ header (ULONGLONG)
    MpqHashTableOffset,                
    /// Compressed size of the hash table (ULONGLONG)
    MpqHashTableSize64,                
    /// Size of the hash table, in entries (DWORD)
    MpqHashTableSize,                  
    /// Raw (unfixed) hash table (TMPQBlock [])
    MpqHashTable,                      
    /// Block table offset, relative to MPQ header (ULONGLONG)
    MpqBlockTableOffset,               
    /// Compressed size of the block table (ULONGLONG)
    MpqBlockTableSize64,               
    /// Size of the block table, in entries (DWORD)
    MpqBlockTableSize,                 
    /// Raw (unfixed) block table (TMPQBlock [])
    MpqBlockTable,                     
    /// Hi-block table offset, relative to MPQ header (ULONGLONG)
    MpqHiBlockTableOffset,             
    /// Compressed size of the hi-block table (ULONGLONG)
    MpqHiBlockTableSize64,             
    /// The hi-block table (USHORT [])
    MpqHiBlockTable,                   
    /// Signatures present in the MPQ (DWORD)
    MpqSignatures,                     
    /// Byte offset of the strong signature, relative to begin of the file (ULONGLONG)
    MpqStrongSignatureOffset,          
    /// Size of the strong signature (DWORD)
    MpqStrongSignatureSize,            
    /// The strong signature (BYTE [])
    MpqStrongSignature,                
    /// Archive size from the header (ULONGLONG)
    MpqArchiveSize64,                  
    /// Archive size from the header (DWORD)
    MpqArchiveSize,                    
    /// Max number of files in the archive (DWORD)
    MpqMaxFileCount,                   
    /// Number of entries in the file table (DWORD)
    MpqFileTableSize,                  
    /// Sector size (DWORD)
    MpqSectorSize,                     
    /// Number of files (DWORD)
    MpqNumberOfFiles,                  
    /// Size of the raw data chunk for MD5
    MpqRawChunkSize,                   
    /// Stream flags (DWORD)
    MpqStreamFlags,                    
    /// Nonzero if the MPQ is read only (DWORD)
    MpqIsReadOnly,                     

    // Info classes for files
    /// Chain of patches where the file is (TCHAR [])
    InfoPatchChain,                    
    /// The file entry for the file (TFileEntry)
    InfoFileEntry,                     
    /// Hash table entry for the file (TMPQHash)
    InfoHashEntry,                     
    /// Index of the hash table entry (DWORD)
    InfoHashIndex,                     
    /// The first name hash in the hash table (DWORD)
    InfoNameHash1,                     
    /// The second name hash in the hash table (DWORD)
    InfoNameHash2,                     
    /// 64-bit file name hash for the HET/BET tables (ULONGLONG)
    InfoNameHash3,                     
    /// File locale (DWORD)
    InfoLocale,                        
    /// Block index (DWORD)
    InfoFileIndex,                     
    /// File position in the archive (ULONGLONG)
    InfoByteOffset,                    
    /// File time (ULONGLONG)
    InfoFileTime,                      
    /// Size of the file (DWORD)
    InfoFileSize,                      
    /// Compressed file size (DWORD)
    InfoCompressedSize,                
    /// File flags from (DWORD)
    InfoFlags,                         
    /// File encryption key
    InfoEncryptionKey,                 
    /// Unfixed value of the file key
    InfoEncryptionKeyRaw,              
}