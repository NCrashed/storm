/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.filestream;

import storm.callback;
import storm.constants;
import storm.errors;

/// Structure used by FileStream_GetBitmap
struct TStreamBitmap
{
    /// Size of the stream, in bytes
    ulong StreamSize;                       
    /// Size of the block map, in bytes
    uint BitmapSize;                           
    /// Number of blocks in the stream
    uint BlockCount;                           
    /// Size of one block
    uint BlockSize;                            
    /// Nonzero if the file is complete
    uint IsComplete;                           

    // Followed by the BYTE array, each bit means availability of one block
}

/**
*   This function creates a new file for read-write access
*
*   - If the current platform supports file sharing,
*     the file must be created for read sharing (i.e. another application
*     can open the file for read, but not for write)
*   - If the file does not exist, the function must create new one
*   - If the file exists, the function must rewrite it and set to zero size
*   - The parameters of the function must be validate by the caller
*   - The function must initialize all stream function pointers in TFileStream
*   - If the function fails from any reason, it must close all handles
*     and free all memory that has been allocated in the process of stream creation,
*     including the TFileStream structure itself
*
*   Params:
*       szFileName  Name of the file to create
*/
TFileStream FileStream_CreateFile(
    string szFileName,
    uint   dwStreamFlags)
{
    TFileStream pStream;

    // We only support creation of flat, local file
    if((dwStreamFlags & (STREAM_PROVIDERS_MASK)) != (STREAM_PROVIDER_FLAT | BASE_PROVIDER_FILE))
    {
        SetLastError(ERROR_NOT_SUPPORTED);
        return null;
    }

    // Allocate file stream structure for flat stream
    pStream = AllocateFileStream!TFileStream(szFileName, dwStreamFlags);
    if(pStream !is null)
    {
        // Attempt to create the disk file
        if(BaseFile_Create(pStream))
        {
            // Fill the stream provider functions
            pStream.StreamRead    = pStream.BaseRead;
            pStream.StreamWrite   = pStream.BaseWrite;
            pStream.StreamResize  = pStream.BaseResize;
            pStream.StreamGetSize = pStream.BaseGetSize;
            pStream.StreamGetPos  = pStream.BaseGetPos;
            pStream.StreamClose   = pStream.BaseClose;
            return pStream;
        }

        // File create failed, delete the stream
        pStream = null;
    }

    // Return the stream
    return pStream;
}

/**
*  This function opens an existing file for read or read-write access
*  - If the current platform supports file sharing,
*    the file must be open for read sharing (i.e. another application
*    can open the file for read, but not for write)
*  - If the file does not exist, the function must return null
*  - If the file exists but cannot be open, then function must return null
*  - The parameters of the function must be validate by the caller
*  - The function must initialize all stream function pointers in TFileStream
*  - If the function fails from any reason, it must close all handles
*    and free all memory that has been allocated in the process of stream creation,
*     including the TFileStream structure itself
*
*   Params:
*      szFileName       Name of the file to open
*      dwStreamFlags    specifies the provider and base storage type
*/
TFileStream FileStream_OpenFile(
    string szFileName,
    uint dwStreamFlags)
{
    uint dwProvider = dwStreamFlags & STREAM_PROVIDERS_MASK;
    size_t nPrefixLength = FileStream_Prefix(szFileName, &dwProvider);

    // Re-assemble the stream flags
    dwStreamFlags = (dwStreamFlags & STREAM_OPTIONS_MASK) | dwProvider;
    szFileName = szFileName[nPrefixLength..$];

    // Perform provider-specific open
    switch(dwStreamFlags & STREAM_PROVIDER_MASK)
    {
        case STREAM_PROVIDER_FLAT:
            return FlatStream_Open(szFileName, dwStreamFlags);

        case STREAM_PROVIDER_PARTIAL:
            return PartStream_Open(szFileName, dwStreamFlags);

        case STREAM_PROVIDER_MPQE:
            return MpqeStream_Open(szFileName, dwStreamFlags);

        case STREAM_PROVIDER_BLOCK4:
            return Block4Stream_Open(szFileName, dwStreamFlags);

        default:
            SetLastError(ERROR_INVALID_PARAMETER);
            return null;
    }
}

/**
*   Returns the file name of the stream
*
*   Params:
*      pStream  Pointer to an open stream
*/
string FileStream_GetFileName(TFileStream  pStream)
{
    assert(pStream !is null);
    return pStream.szFileName;
}

/**
*   Returns the length of the provider prefix. Returns zero if no prefix
*
*   Params:
*       szFileName          Pointer to a stream name (file, mapped file, URL)
*       pdwStreamProvider   Pointer to a DWORD variable that receives stream provider (STREAM_PROVIDER_XXX)
*/
size_t FileStream_Prefix(string szFileName, uint * pdwProvider)
{
    size_t nPrefixLength1 = 0;
    size_t nPrefixLength2 = 0;
    uint dwProvider = 0;

    if(szFileName !is null)
    {
        //
        // Determine the stream provider
        //

        if(!szFileName.find("flat-").empty)
        {
            dwProvider |= STREAM_PROVIDER_FLAT;
            nPrefixLength1 = 5;
        }
        else if(!szFileName.find("part-").empty)
        {
            dwProvider |= STREAM_PROVIDER_PARTIAL;
            nPrefixLength1 = 5;
        }
        else if(!szFileName.find("mpqe-").empty)
        {
            dwProvider |= STREAM_PROVIDER_MPQE;
            nPrefixLength1 = 5;
        }
        else if(!szFileName.find("blk4-").empty)
        {
            dwProvider |= STREAM_PROVIDER_BLOCK4;
            nPrefixLength1 = 5;
        }

        //
        // Determine the base provider
        //

        if(!szFileName[nPrefixLength1..$].find("file:").empty)
        {
            dwProvider |= BASE_PROVIDER_FILE;
            nPrefixLength2 = 5;
        }
        else if(!szFileName[nPrefixLength1..$].find("map:").empty)
        {
            dwProvider |= BASE_PROVIDER_MAP;
            nPrefixLength2 = 4;
        }
        else if(!szFileName[nPrefixLength1..$].find("http:").empty)
        {
            dwProvider |= BASE_PROVIDER_HTTP;
            nPrefixLength2 = 5;
        }

        // Only accept stream provider if we recognized the base provider
        if(nPrefixLength2 != 0)
        {
            // It is also allowed to put "//" after the base provider, e.g. "file://", "http://"
            if(szFileName[nPrefixLength1+nPrefixLength2] == '/' && szFileName[nPrefixLength1+nPrefixLength2+1] == '/')
                nPrefixLength2 += 2;

            if(pdwProvider !is null)
                *pdwProvider = dwProvider;
            return nPrefixLength1 + nPrefixLength2;
        }
    }

    return 0;
}

/**
*   Sets a download callback. Whenever the stream needs to download one or more blocks
*   from the server, the callback is called
*
*   Params:
*       pStream     Pointer to an open stream
*       pfnCallback Pointer to callback function
*       pvUserData  Arbitrary user pointer passed to the download callback
*/
bool FileStream_SetCallback(TFileStream pStream, SFILE_DOWNLOAD_CALLBACK pfnCallback, void * pvUserData)
{
    TBlockStream  pBlockStream = cast(TBlockStream)pStream;
    assert(pBlockStream !is null);
    
    if(pStream.BlockRead is null)
    {
        SetLastError(ERROR_NOT_SUPPORTED);
        return false;
    }

    pBlockStream.pfnCallback = pfnCallback;
    pBlockStream.UserData = pvUserData;
    return true;
}

/**
*   This function gives the block map. The 'pvBitmap' pointer must point to a buffer
*   of at least sizeof(STREAM_BLOCK_MAP) size. It can also have size of the complete
*   block map (i.e. sizeof(STREAM_BLOCK_MAP) + BitmapSize). In that case, the function
*   also copies the bit-based block map.
*
*   Params:
*       pStream         Pointer to an open stream
*       pvBitmap        Pointer to buffer where the block map will be stored
*       cbLengthNeeded  Length of the bitmap, in bytes
*/
bool FileStream_GetBitmap(TFileStream pStream, ubyte[] pvBitmap, out size_t pcbLengthNeeded)
{
    TStreamBitmap* pBitmap = cast(TStreamBitmap*)pvBitmap.ptr;
    TBlockStream pBlockStream = cast(TBlockStream)pStream;
    assert(pBlockStream !is null);
    ulong BlockOffset;
    ubyte* Bitmap = cast(ubyte*)(pBitmap + 1);
    uint BitmapSize;
    uint BlockCount;
    uint BlockSize;
    bool bResult = false;

    // Retrieve the size of one block
    if(pStream.BlockCheck !is null)
    {
        BlockCount = pBlockStream.BlockCount;
        BlockSize = pBlockStream.BlockSize;
    }
    else
    {
        BlockCount = cast(uint)((pStream.StreamSize + DEFAULT_BLOCK_SIZE - 1) / DEFAULT_BLOCK_SIZE);
        BlockSize = DEFAULT_BLOCK_SIZE;
    }

    // Fill-in the variables
    BitmapSize = (BlockCount + 7) / 8;

    // Give the number of blocks
    pcbLengthNeeded = TStreamBitmap.sizeof + BitmapSize;

    // If the length of the buffer is not enough
    if(pvBitmap !is null && pvBitmap.length != 0)
    {
        // Give the STREAM_BLOCK_MAP structure
        if(pvBitmap.length >= TStreamBitmap.sizeof)
        {
            pBitmap.StreamSize = pStream.StreamSize;
            pBitmap.BitmapSize = BitmapSize;
            pBitmap.BlockCount = BlockCount;
            pBitmap.BlockSize  = BlockSize;
            pBitmap.IsComplete = (pStream.BlockCheck !is null) ? pBlockStream.IsComplete : 1;
            bResult = true;
        }

        // Give the block bitmap, if enough space
        if(pvBitmap.length >= TStreamBitmap.sizeof + BitmapSize)
        {
            // Version with bitmap present
            if(pStream.BlockCheck !is null)
            {
                uint ByteIndex = 0;
                ubyte BitMask = 0x01;

                // Initialize the map with zeros
                Bitmap[0 .. BitmapSize] = 0;

                // Fill the map
                for(BlockOffset = 0; BlockOffset < pStream.StreamSize; BlockOffset += BlockSize)
                {
                    // Set the bit if the block is present
                    if(pBlockStream.BlockCheck(pStream, BlockOffset))
                        Bitmap[ByteIndex] |= BitMask;

                    // Move bit position
                    ByteIndex += (BitMask >> 0x07);
                    BitMask = cast(ubyte)((BitMask >> 0x07) | (BitMask << 0x01));
                }
            }
            else
            {
                Bitmap[0 .. BitmapSize] = 0xFF;
            }
        }
    }

    // Set last error value and return
    if(bResult == false)
        SetLastError(ERROR_INSUFFICIENT_BUFFER);
    return bResult;
}

/**
*   Reads data from the stream
*
*   - Returns true if the read operation succeeded and all bytes have been read
*   - Returns false if either read failed or not all bytes have been read
*   - If the pByteOffset is null, the function must read the data from the current file position
*   - The function can be called with dwBytesToRead = 0. In that case, pvBuffer is ignored
*     and the function just adjusts file pointer.
*
*   Params:
*       pStream         Pointer to an open stream
*       pByteOffset     Pointer to file byte offset. If null, it reads from the current position
*       pvBuffer        Pointer to data to be read
*       dwBytesToRead   Number of bytes to read from the file
*
*   Returns:
*   - If the function reads the required amount of bytes, it returns true.
*   - If the function reads less than required bytes, it returns false and GetLastError() returns ERROR_HANDLE_EOF
*   - If the function fails, it reads false and GetLastError() returns an error code different from ERROR_HANDLE_EOF
*/
bool FileStream_Read(TFileStream pStream, ulong * pByteOffset, ubyte[] pvBuffer)
{
    assert(pStream.StreamRead !is null);
    return pStream.StreamRead(pStream, pByteOffset, pvBuffer);
}

/**
*   This function writes data to the stream
*
*   - Returns true if the write operation succeeded and all bytes have been written
*   - Returns false if either write failed or not all bytes have been written
*   - If the pByteOffset is null, the function must write the data to the current file position
*
*   Params:
*       pStream     Pointer to an open stream
*       pByteOffset Pointer to file byte offset. If null, it reads from the current position
*       pvBuffer    Pointer to data to be written
*/
bool FileStream_Write(TFileStream pStream, ulong* pByteOffset, const ubyte[] pbBuffer)
{
    if(pStream.dwFlags & STREAM_FLAG_READ_ONLY)
    {
        SetLastError(ERROR_ACCESS_DENIED);
        return false;
    }

    assert(pStream.StreamWrite !is null);
    return pStream.StreamWrite(pStream, pByteOffset, pbBuffer);
}

/**
*   Returns the size of a file
*   
*   Params:
*       pStream     Pointer to an open stream
*       FileSize    Pointer where to store the file size
*/
bool FileStream_GetSize(TFileStream pStream, out ulong pFileSize)
{
    assert(pStream.StreamGetSize !is null);
    return pStream.StreamGetSize(pStream, pFileSize);
}

/**
*   Sets the size of a file
*
*   Params:
*       pStream     Pointer to an open stream
*       NewFileSize File size to set
*/
bool FileStream_SetSize(TFileStream pStream, ulong NewFileSize)
{                                 
    if(pStream.dwFlags & STREAM_FLAG_READ_ONLY)
    {
        SetLastError(ERROR_ACCESS_DENIED);
        return false;
    }

    assert(pStream.StreamResize !is null);
    return pStream.StreamResize(pStream, NewFileSize);
}

/**
*   This function returns the current file position.
*
*   Params:
*       pStream
*       pByteOffset
*/
bool FileStream_GetPos(TFileStream pStream, out ulong pByteOffset)
{
    assert(pStream.StreamGetPos !is null);
    return pStream.StreamGetPos(pStream, pByteOffset);
}

/**
*   Returns the last write time of a file
*
*   Params:
*       pStream     Pointer to an open stream
*       pFileType   Pointer where to store the file last write time
*/
bool FileStream_GetTime(TFileStream pStream, out ulong pFileTime)
{
    // Just use the saved filetime value
    pFileTime = pStream.Base.File.FileTime;
    return true;
}

/**
*   Returns the stream flags
*
*   Params:
*       pStream         Pointer to an open stream
*       pdwStreamFlags  Pointer where to store the stream flags
*/
bool FileStream_GetFlags(TFileStream pStream, out uint pdwStreamFlags)
{
    pdwStreamFlags = pStream.dwFlags;
    return true;
}

/**
*   Switches a stream with another. Used for final phase of archive compacting.
*   Performs these steps:
*
*   1) Closes the handle to the existing MPQ
*   2) Renames the temporary MPQ to the original MPQ, overwrites existing one
*   3) Opens the MPQ stores the handle and stream position to the new stream structure
*
*   Params:
*       pStream     Pointer to an open stream
*       pNewStream  Temporary ("working") stream (created during archive compacting)
*/
bool FileStream_Replace(TFileStream pStream, TFileStream pNewStream)
{
    // Only supported on flat files
    if((pStream.dwFlags & STREAM_PROVIDERS_MASK) != (STREAM_PROVIDER_FLAT | BASE_PROVIDER_FILE))
    {
        SetLastError(ERROR_NOT_SUPPORTED);
        return false;
    }

    // Not supported on read-only streams
    if(pStream.dwFlags & STREAM_FLAG_READ_ONLY)
    {
        SetLastError(ERROR_ACCESS_DENIED);
        return false;
    }

    // Close both stream's base providers
    pNewStream.BaseClose(pNewStream);
    pStream.BaseClose(pStream);

    // Now we have to delete the (now closed) old file and rename the new file
    if(!BaseFile_Replace(pStream, pNewStream))
        return false;

    // Now open the base file again
    if(!BaseFile_Open(pStream, pStream.szFileName, pStream.dwFlags))
        return false;

    // Cleanup the new stream
    FileStream_Close(pNewStream);
    return true;
}

/**
*   This function closes an archive file and frees any data buffers
*   that have been allocated for stream management. The function must also
*   support partially allocated structure, i.e. one or more buffers
*   can be null, if there was an allocation failure during the process
*
*   Params:
*       pStream     Pointer to an open stream
*/
void FileStream_Close(TFileStream pStream)
{
    // Check if the stream structure is allocated at all
    if(pStream !is null)
    {
        // Free the master stream, if any
        if(pStream.pMaster !is null)
            FileStream_Close(pStream.pMaster);
        pStream.pMaster = null;

        // Close the stream provider.
        if(pStream.StreamClose !is null)
            pStream.StreamClose(pStream);
        
        // Also close base stream, if any
        else if(pStream.BaseClose !is null)
            pStream.BaseClose(pStream);
    }
}

//=============================================================================
package:

version(Windows) import core.sys.windows.windows;
version(Posix)
{
    import core.stdc.stdio;
    import core.sys.posix.fcntl;
    import core.sys.posix.sys.stat;
    import core.sys.posix.sys.types;
    import core.sys.posix.unistd;
    import core.sys.posix.sys.mman;
    import core.stdc.errno;
}

import std.string;
import std.algorithm;
import std.range;
import std.conv;

import storm.swapping;

enum INVALID_HANDLE_VALUE = cast(void*)(cast(size_t)-1);

//-----------------------------------------------------------------------------
// Function prototypes

alias STREAM_INIT = void function(
    TFileStream pStream        // Pointer to an unopened stream
    );

alias STREAM_CREATE = bool function(
    TFileStream pStream        // Pointer to an unopened stream
    );

alias STREAM_OPEN = bool function(
    TFileStream pStream,           // Pointer to an unopened stream
    string szFileName,             // Pointer to file name to be open
    uint dwStreamFlags             // Stream flags
    );

alias STREAM_READ = bool function(
    TFileStream pStream,                // Pointer to an open stream
    ulong* pByteOffset,                 // Pointer to file byte offset. If null, it reads from the current position
    ubyte[] pvBuffer                    // Pointer to data to be read
    );

alias STREAM_WRITE = bool function(
    TFileStream pStream,            // Pointer to an open stream
    ulong* pByteOffset,             // Pointer to file byte offset. If null, it writes to the current position
    const ubyte[] pvBuffer          // Pointer to data to be written
    );

alias STREAM_RESIZE = bool function(
    TFileStream pStream,           // Pointer to an open stream
    ulong FileSize                  // New size for the file, in bytes
    );

alias STREAM_GETSIZE = bool function(
    TFileStream pStream,           // Pointer to an open stream
    out ulong pFileSize             // Receives the file size, in bytes
    );

alias STREAM_GETPOS = bool function(
    TFileStream pStream,           // Pointer to an open stream
    out ulong pByteOffset           // Pointer to store current file position
    );

alias STREAM_CLOSE = void function(
    TFileStream pStream            // Pointer to an open stream
    );

alias BLOCK_READ = bool function(
    TFileStream pStream,            // Pointer to a block-oriented stream
    ulong StartOffset,              // Byte offset of start of the block array
    ulong EndOffset,                // End offset (either end of the block or end of the file)
    ubyte[] BlockBuffer,            // Pointer to block-aligned buffer
    size_t BytesNeeded,             // Number of bytes that are really needed
    bool bAvailable                 // true if the block is available
    );

alias BLOCK_CHECK = bool function(
    TFileStream pStream,              // Pointer to a block-oriented stream
    ulong BlockOffset                 // Offset of the file to check
    );

alias BLOCK_SAVEMAP = void function(
    TFileStream pStream          // Pointer to a block-oriented stream
    );

//-----------------------------------------------------------------------------
// Local structures - partial file structure and bitmap footer

/// Signature of the file bitmap footer ('ptv3')
enum ID_FILE_BITMAP_FOOTER  = 0x33767470;  
/// Default size of the stream block
enum DEFAULT_BLOCK_SIZE     = 0x00004000;  
/// Build number for newly created partial MPQs
enum DEFAULT_BUILD_NUMBER        = 10958;  

struct PART_FILE_HEADER
{
    uint PartialVersion;                   // Always set to 2
    char[0x20] GameBuildNumber;            // Minimum build number of the game that can use this MPQ
    uint Flags;                            // Flags (details unknown)
    uint FileSizeLo;                       // Low 32 bits of the contained file size
    uint FileSizeHi;                       // High 32 bits of the contained file size
    uint BlockSize;                        // Size of one file block, in bytes
}

// Structure describing the block-to-file map entry
struct PART_FILE_MAP_ENTRY
{
    uint Flags;                            // 3 = the block is present in the file
    uint BlockOffsLo;                      // Low 32 bits of the block position in the file
    uint BlockOffsHi;                      // High 32 bits of the block position in the file
    uint LargeValueLo;                     // 64-bit value, meaning is unknown
    uint LargeValueHi;
}

struct FILE_BITMAP_FOOTER
{
    uint Signature;                      // 'ptv3' (ID_FILE_BITMAP_FOOTER)
    uint Version;                        // Unknown, seems to always have value of 3 (version?)
    uint BuildNumber;                    // Game build number for that MPQ
    uint MapOffsetLo;                    // Low 32-bits of the offset of the bit map
    uint MapOffsetHi;                    // High 32-bits of the offset of the bit map
    uint BlockSize;                      // Size of one block (usually 0x4000 bytes)
}

//-----------------------------------------------------------------------------
// Structure for file stream

union TBaseProviderData
{
    struct SFile
    {
        ulong FileSize;                 // Size of the file
        ulong FilePos;                  // Current file position
        ulong FileTime;                 // Last write time
        void* hFile;                    // File handle
    }

    struct SMap
    {
        ulong FileSize;                 // Size of the file
        ulong FilePos;                  // Current file position
        ulong FileTime;                 // Last write time
        ubyte* pbFile;                  // Pointer to mapped view
    }

    struct SHttp
    {
        ulong FileSize;                 // Size of the file
        ulong FilePos;                  // Current file position
        ulong FileTime;                 // Last write time
        void* hInternet;                // Internet handle
        void* hConnect;                 // Connection to the internet server
    }
    
    SFile File;
    SMap  Map;
    SHttp Http;
}

class TFileStream
{
    // Stream provider functions
    STREAM_READ    StreamRead;              // Pointer to stream read function for this archive. Do not use directly.
    STREAM_WRITE   StreamWrite;             // Pointer to stream write function for this archive. Do not use directly.
    STREAM_RESIZE  StreamResize;            // Pointer to function changing file size
    STREAM_GETSIZE StreamGetSize;           // Pointer to function returning file size
    STREAM_GETPOS  StreamGetPos;            // Pointer to function that returns current file position
    STREAM_CLOSE   StreamClose;             // Pointer to function closing the stream

    // Block-oriented functions
    BLOCK_READ     BlockRead;               // Pointer to function reading one or more blocks
    BLOCK_CHECK    BlockCheck;              // Pointer to function checking whether the block is present

    // Base provider functions
    STREAM_CREATE  BaseCreate;              // Pointer to base create function
    STREAM_OPEN    BaseOpen;                // Pointer to base open function
    STREAM_READ    BaseRead;                // Read from the stream
    STREAM_WRITE   BaseWrite;               // Write to the stream
    STREAM_RESIZE  BaseResize;              // Pointer to function changing file size
    STREAM_GETSIZE BaseGetSize;             // Pointer to function returning file size
    STREAM_GETPOS  BaseGetPos;              // Pointer to function that returns current file position
    STREAM_CLOSE   BaseClose;               // Pointer to function closing the stream

    // Base provider data (file size, file position)
    TBaseProviderData Base;

    // Stream provider data
    TFileStream pMaster;                    // Master stream (e.g. MPQ on a web server)
    string szFileName;                      // File name (self-relative pointer)

    ulong StreamSize;                      // Stream size (can be less than file size)
    ulong StreamPos;                       // Stream position
    uint BuildNumber;                      // Game build number
    uint dwFlags;                          // Stream flags

    // Followed by stream provider data, with variable length
}

//-----------------------------------------------------------------------------
// Structures for block-oriented stream

class TBlockStream : TFileStream
{
    SFILE_DOWNLOAD_CALLBACK pfnCallback;    // Callback for downloading
    ubyte[] FileBitmap;                     // Array of bits for file blocks
    void * UserData;                        // User data to be passed to the download callback
    uint BitmapSize;                        // Size of the file bitmap (in bytes)
    uint BlockSize;                         // Size of one block, in bytes
    uint BlockCount;                        // Number of data blocks in the file
    uint IsComplete;                        // If nonzero, no blocks are missing
    uint IsModified;                        // nonzero if the bitmap has been modified
}       

//-----------------------------------------------------------------------------
// Structure for encrypted stream

enum MPQE_CHUNK_SIZE = 0x40;                // Size of one chunk to be decrypted

class TEncryptedStream : TBlockStream
{
    ubyte[MPQE_CHUNK_SIZE] Key;              // File key
}

//-----------------------------------------------------------------------------
// Dummy init function

static void BaseNone_Init(TFileStream)
{
    // Nothing here
}

//-----------------------------------------------------------------------------
// Local functions - base file support

bool BaseFile_Create(TFileStream pStream)
{
    version(Windows)
    {
        DWORD dwWriteShare = (pStream.dwFlags & STREAM_FLAG_WRITE_SHARE) ? FILE_SHARE_WRITE : 0;

        pStream.Base.File.hFile = CreateFile(pStream.szFileName.toStringz,
                                              GENERIC_READ | GENERIC_WRITE,
                                              dwWriteShare | FILE_SHARE_READ,
                                              null,
                                              CREATE_ALWAYS,
                                              0,
                                              null);
        if(pStream.Base.File.hFile == INVALID_HANDLE_VALUE)
            return false;
    }


    version(Posix)
    {
        intptr_t handle;
        
        handle = open64(pStream.szFileName.toStringz, O_RDWR | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        if(handle == -1)
        {
            SetLastError(errno);
            return false;
        }
        
        pStream.Base.File.hFile = cast(void*)handle;
    }

    // Reset the file size and position
    pStream.Base.File.FileSize = 0;
    pStream.Base.File.FilePos = 0;
    return true;
}

bool BaseFile_Open(TFileStream pStream, string szFileName, uint dwStreamFlags)
{
    version(Windows)
    {
        ULARGE_INTEGER FileSize;
        DWORD dwWriteAccess = (dwStreamFlags & STREAM_FLAG_READ_ONLY) ? 0 : FILE_WRITE_DATA | FILE_APPEND_DATA | FILE_WRITE_ATTRIBUTES;
        DWORD dwWriteShare = (dwStreamFlags & STREAM_FLAG_WRITE_SHARE) ? FILE_SHARE_WRITE : 0;

        // Open the file
        pStream.Base.File.hFile = CreateFile(szFileName,
                                              FILE_READ_DATA | FILE_READ_ATTRIBUTES | dwWriteAccess,
                                              FILE_SHARE_READ | dwWriteShare,
                                              null,
                                              OPEN_EXISTING,
                                              0,
                                              null);
        if(pStream.Base.File.hFile == INVALID_HANDLE_VALUE)
            return false;

        // Query the file size
        FileSize.LowPart = GetFileSize(pStream.Base.File.hFile, &FileSize.HighPart);
        pStream.Base.File.FileSize = FileSize.QuadPart;

        // Query last write time
        GetFileTime(pStream.Base.File.hFile, null, null, (LPFILETIME)&pStream.Base.File.FileTime);
    }

    version(Posix)
    {
        stat_t fileinfo;
        int oflag = (dwStreamFlags & STREAM_FLAG_READ_ONLY) ? O_RDONLY : O_RDWR;
        intptr_t handle;

        // Open the file
        handle = open64(szFileName.toStringz, oflag);
        if(handle == -1)
        {
            SetLastError(errno);
            return false;
        }

        // Get the file size
        if(fstat64(cast(int)handle, &fileinfo) == -1)
        {
            SetLastError(errno);
            return false;
        }

        // time_t is number of seconds since 1.1.1970, UTC.
        // 1 second = 10000000 (decimal) in FILETIME
        // Set the start to 1.1.1970 00:00:00
        pStream.Base.File.FileTime = 0x019DB1DED53E8000U + (10000000 * fileinfo.st_mtime);
        pStream.Base.File.FileSize = cast(ulong)fileinfo.st_size;
        pStream.Base.File.hFile = cast(void*)handle;
    }

    // Reset the file position
    pStream.Base.File.FilePos = 0;
    return true;
}

static bool BaseFile_Read(
    TFileStream   pStream,                  // Pointer to an open stream
    ulong * pByteOffset,                    // Pointer to file byte offset. If null, it reads from the current position
    ubyte[] pvBuffer)                       // Pointer to data to be read
{
    ulong ByteOffset = (pByteOffset !is null) ? *pByteOffset : pStream.Base.File.FilePos;
    uint dwBytesRead = 0;                  // Must be set by platform-specific code

    version(Windows)
    {
        // Note: StormLib no longer supports Windows 9x.
        // Thus, we can use the OVERLAPPED structure to specify
        // file offset to read from file. This allows us to skip
        // one system call to SetFilePointer

        // Update the byte offset
        pStream.Base.File.FilePos = ByteOffset;

        // Read the data
        if(pvBuffer.length != 0)
        {
            OVERLAPPED Overlapped;

            Overlapped.OffsetHigh = cast(DWORD)(ByteOffset >> 32);
            Overlapped.Offset = cast(DWORD)ByteOffset;
            Overlapped.hEvent = null;
            if(!ReadFile(pStream.Base.File.hFile, pvBuffer.ptr, pvBuffer.length, &dwBytesRead, &Overlapped))
                return false;
        }
    }

    version(Posix)
    {
        ssize_t bytes_read;

        // If the byte offset is different from the current file position,
        // we have to update the file position
        if(ByteOffset != pStream.Base.File.FilePos)
        {
            lseek64(cast(int)pStream.Base.File.hFile, cast(off_t)(ByteOffset), SEEK_SET);
            pStream.Base.File.FilePos = ByteOffset;
        }

        // Perform the read operation
        if(pvBuffer.length != 0)
        {
            bytes_read = read(cast(int)pStream.Base.File.hFile, pvBuffer.ptr, pvBuffer.length);
            if(bytes_read == -1)
            {
                SetLastError(errno);
                return false;
            }
            
            dwBytesRead = cast(uint)cast(size_t)bytes_read;
        }
    }

    // Increment the current file position by number of bytes read
    // If the number of bytes read doesn't match to required amount, return false
    pStream.Base.File.FilePos = ByteOffset + dwBytesRead;
    if(dwBytesRead != pvBuffer.length)
        SetLastError(ERROR_HANDLE_EOF);
    return (dwBytesRead == pvBuffer.length);
}

/**
*   Params:
*       pStream         Pointer to an open stream
*       pByteOffset     Pointer to file byte offset. If null, writes to current position
*       pvBuffer        Pointer to data to be written
*       dwBytesToWrite  Number of bytes to write to the file
*/
bool BaseFile_Write(TFileStream pStream, ulong * pByteOffset, const ubyte[] pvBuffer)
{
    ulong ByteOffset = (pByteOffset !is null) ? *pByteOffset : pStream.Base.File.FilePos;
    uint dwBytesWritten = 0;               // Must be set by platform-specific code

    version(Windows)
    {
        // Note: StormLib no longer supports Windows 9x.
        // Thus, we can use the OVERLAPPED structure to specify
        // file offset to read from file. This allows us to skip
        // one system call to SetFilePointer

        // Update the byte offset
        pStream.Base.File.FilePos = ByteOffset;

        // Write the data
        if(pvBuffer.length != 0)
        {
            OVERLAPPED Overlapped;

            Overlapped.OffsetHigh = cast(DWORD)(ByteOffset >> 32);
            Overlapped.Offset = cast(DWORD)ByteOffset;
            Overlapped.hEvent = null;
            if(!WriteFile(pStream.Base.File.hFile, pvBuffer.ptr, pvBuffer.length, &dwBytesWritten, &Overlapped))
                return false;
        }
    }

    version(Posix)
    {
        ssize_t bytes_written;

        // If the byte offset is different from the current file position,
        // we have to update the file position
        if(ByteOffset != pStream.Base.File.FilePos)
        {
            lseek64(cast(int)pStream.Base.File.hFile, cast(off_t)(ByteOffset), SEEK_SET);
            pStream.Base.File.FilePos = ByteOffset;
        }

        // Perform the read operation
        bytes_written = write(cast(int)pStream.Base.File.hFile, pvBuffer.ptr, pvBuffer.length);
        if(bytes_written == -1)
        {
            SetLastError(errno);
            return false;
        }
        
        dwBytesWritten = cast(uint)cast(size_t)bytes_written;
    }

    // Increment the current file position by number of bytes read
    pStream.Base.File.FilePos = ByteOffset + dwBytesWritten;

    // Also modify the file size, if needed
    if(pStream.Base.File.FilePos > pStream.Base.File.FileSize)
        pStream.Base.File.FileSize = pStream.Base.File.FilePos;

    if(dwBytesWritten != pvBuffer.length)
        SetLastError(ERROR_DISK_FULL);
    return (dwBytesWritten == pvBuffer.length);
}

/**
*   Params:
*      pStream     Pointer to an open stream
*      NewFileSize New size of the file
*/
bool BaseFile_Resize(TFileStream pStream, ulong NewFileSize)
{
    version(Windows)
    {
        LONG FileSizeHi = cast(LONG)(NewFileSize >> 32);
        LONG FileSizeLo;
        DWORD dwNewPos;
        bool bResult;

        // Set the position at the new file size
        dwNewPos = SetFilePointer(pStream.Base.File.hFile, cast(LONG)NewFileSize, &FileSizeHi, FILE_BEGIN);
        if(dwNewPos == INVALID_SET_FILE_POINTER && GetLastError() != ERROR_SUCCESS)
            return false;

        // Set the current file pointer as the end of the file
        bResult = cast(bool)SetEndOfFile(pStream.Base.File.hFile);
        if(bResult)
            pStream.Base.File.FileSize = NewFileSize;

        // Restore the file position
        FileSizeHi = cast(LONG)(pStream.Base.File.FilePos >> 32);
        FileSizeLo = cast(LONG)(pStream.Base.File.FilePos);
        SetFilePointer(pStream.Base.File.hFile, FileSizeLo, &FileSizeHi, FILE_BEGIN);
        return bResult;
    }
    
    version(Posix)
    {
        if(ftruncate64(cast(int)pStream.Base.File.hFile, cast(off_t)NewFileSize) == -1)
        {
            SetLastError(errno);
            return false;
        }
        
        pStream.Base.File.FileSize = NewFileSize;
        return true;
    }
}

// Gives the current file size
bool BaseFile_GetSize(TFileStream pStream, out ulong pFileSize)
{
    // Note: Used by all three base providers.
    // Requires the TBaseData union to have the same layout for all three base providers
    pFileSize = pStream.Base.File.FileSize;
    return true;
}

// Gives the current file position
bool BaseFile_GetPos(TFileStream pStream, out ulong pByteOffset)
{
    // Note: Used by all three base providers.
    // Requires the TBaseData union to have the same layout for all three base providers
    pByteOffset = pStream.Base.File.FilePos;
    return true;
}

// Renames the file pointed by pStream so that it contains data from pNewStream
bool BaseFile_Replace(TFileStream pStream, TFileStream pNewStream)
{
    version(Windows)
    {
        // Delete the original stream file. Don't check the result value,
        // because if the file doesn't exist, it would fail
        DeleteFile(pStream.szFileName.toStringz);
    
        // Rename the new file to the old stream's file
        return cast(bool)MoveFile(pNewStream.szFileName.toStringz, pStream.szFileName.toStringz);
    }
    
    version(Posix)
    {
        // "rename" on Linux also works if the target file exists
        if(rename(pNewStream.szFileName.toStringz, pStream.szFileName.toStringz) == -1)
        {
            SetLastError(errno);
            return false;
        }
        
        return true;
    }
}

void BaseFile_Close(TFileStream pStream)
{
    if(pStream.Base.File.hFile != INVALID_HANDLE_VALUE)
    {
        version(Windows)
            CloseHandle(pStream.Base.File.hFile);

        version(Posix)
            close(cast(int)pStream.Base.File.hFile);
    }

    // Also invalidate the handle
    pStream.Base.File.hFile = INVALID_HANDLE_VALUE;
}

// Initializes base functions for the disk file
static void BaseFile_Init(TFileStream pStream)
{
    pStream.BaseCreate  = &BaseFile_Create;
    pStream.BaseOpen    = &BaseFile_Open;
    pStream.BaseRead    = &BaseFile_Read;
    pStream.BaseWrite   = &BaseFile_Write;
    pStream.BaseResize  = &BaseFile_Resize;
    pStream.BaseGetSize = &BaseFile_GetSize;
    pStream.BaseGetPos  = &BaseFile_GetPos;
    pStream.BaseClose   = &BaseFile_Close;
}

//-----------------------------------------------------------------------------
// Local functions - base memory-mapped file support

bool BaseMap_Open(TFileStream pStream, string szFileName, uint dwStreamFlags)
{
    version(Windows)
    {
        ULARGE_INTEGER FileSize;
        HANDLE hFile;
        HANDLE hMap;
        bool bResult = false;
    
        // Keep compiler happy
        dwStreamFlags = dwStreamFlags;
    
        // Open the file for read access
        hFile = CreateFile(szFileName.toStringz, FILE_READ_DATA, FILE_SHARE_READ, null, OPEN_EXISTING, 0, null);
        if(hFile !is null)
        {
            // Retrieve file size. Don't allow mapping file of a zero size.
            FileSize.LowPart = GetFileSize(hFile, &FileSize.HighPart);
            if(FileSize.QuadPart != 0)
            {
                // Now create mapping object
                hMap = CreateFileMapping(hFile, null, PAGE_READONLY, 0, 0, null);
                if(hMap !is null)
                {
                    // Map the entire view into memory
                    // Note that this operation will fail if the file can't fit
                    // into usermode address space
                    pStream.Base.Map.pbFile = cast(byte*)MapViewOfFile(hMap, FILE_MAP_READ, 0, 0, 0);
                    if(pStream.Base.Map.pbFile !is null)
                    {
                        // Retrieve file time
                        GetFileTime(hFile, null, null, cast(LPFILETIME)&pStream.Base.Map.FileTime);
    
                        // Retrieve file size and position
                        pStream.Base.Map.FileSize = FileSize.QuadPart;
                        pStream.Base.Map.FilePos = 0;
                        bResult = true;
                    }
    
                    // Close the map handle
                    CloseHandle(hMap);
                }
            }
    
            // Close the file handle
            CloseHandle(hFile);
        }
    
        // If the file is not there and is not available for random access,
        // report error
        if(bResult == false)
            return false;
    }

    version(Posix)
    {
        stat_t fileinfo;
        intptr_t handle;
        bool bResult = false;
    
        // Open the file
        handle = open(szFileName.toStringz, O_RDONLY);
        if(handle != -1)
        {
            // Get the file size
            if(fstat64(cast(int)handle, &fileinfo) != -1)
            {
                pStream.Base.Map.pbFile = cast(ubyte*)mmap(null, cast(size_t)fileinfo.st_size, PROT_READ, MAP_PRIVATE, cast(int)handle, 0);
                if(pStream.Base.Map.pbFile !is null)
                {
                    // time_t is number of seconds since 1.1.1970, UTC.
                    // 1 second = 10000000 (decimal) in FILETIME
                    // Set the start to 1.1.1970 00:00:00
                    pStream.Base.Map.FileTime = 0x019DB1DED53E8000U + (10000000 * fileinfo.st_mtime);
                    pStream.Base.Map.FileSize = cast(ulong)fileinfo.st_size;
                    pStream.Base.Map.FilePos = 0;
                    bResult = true;
                }
            }
            close(cast(int)handle);
        }
    
        // Did the mapping fail?
        if(bResult == false)
        {
            SetLastError(errno);
            return false;
        }
    }

    return true;
}

bool BaseMap_Read(
    TFileStream  pStream,                   // Pointer to an open stream
    ulong * pByteOffset,                    // Pointer to file byte offset. If null, it reads from the current position
    ubyte[] pvBuffer)                       // Pointer to data to be read
{
    ulong ByteOffset = (pByteOffset !is null) ? *pByteOffset : pStream.Base.Map.FilePos;

    // Do we have to read anything at all?
    if(pvBuffer.length != 0)
    {
        // Don't allow reading past file size
        if((ByteOffset + pvBuffer.length) > pStream.Base.Map.FileSize)
            return false;

        // Copy the required data
        memcpy(pvBuffer.ptr, pStream.Base.Map.pbFile + cast(size_t)ByteOffset, pvBuffer.length);
    }

    // Move the current file position
    pStream.Base.Map.FilePos += pvBuffer.length;
    return true;
}

void BaseMap_Close(TFileStream pStream)
{
    version(Windows)
    {
        if(pStream.Base.Map.pbFile !is null)
            UnmapViewOfFile(pStream.Base.Map.pbFile);
    }

    version(Posix)
    {
        if(pStream.Base.Map.pbFile !is null)
            munmap(pStream.Base.Map.pbFile, cast(size_t)pStream.Base.Map.FileSize);
    }

    pStream.Base.Map.pbFile = null;
}

// Initializes base functions for the mapped file
void BaseMap_Init(TFileStream pStream)
{
    // Supply the file stream functions
    pStream.BaseOpen    = &BaseMap_Open;
    pStream.BaseRead    = &BaseMap_Read;
    pStream.BaseGetSize = &BaseFile_GetSize;    // Reuse BaseFile function
    pStream.BaseGetPos  = &BaseFile_GetPos;     // Reuse BaseFile function
    pStream.BaseClose   = &BaseMap_Close;

    // Mapped files are read-only
    pStream.dwFlags |= STREAM_FLAG_READ_ONLY;
}

//-----------------------------------------------------------------------------
// Local functions - base HTTP file support
/// TODO: Add support for CURL for Posix platform!

string BaseHttp_ExtractServerName(string szFileName, out string szServerName)
{
    // Check for HTTP
    if(!szFileName.find("http://").empty)
        szFileName = szFileName[8..$];

    // Cut off the server name
    if(szServerName != "")
    {
        auto i = szFileName.countUntil('/');
        if(i > 0)
        {
           szServerName = szFileName[0..i];
           szFileName = szFileName[i..$];
        }
    }
    else
    {
        auto i = szFileName.countUntil('/');
        if(i > 0)
        {
           szFileName = szFileName[i..$];
        }
    }

    // Return the remainder
    return szFileName;
}

bool BaseHttp_Open(TFileStream  pStream, string szFileName, uint dwStreamFlags)
{
    version(Windows)
    {
        HINTERNET hRequest;
        DWORD dwTemp = 0;
        bool bFileAvailable = false;
        int nError = ERROR_SUCCESS;
    
        // Keep compiler happy
        dwStreamFlags = dwStreamFlags;
    
        // Don't connect to the internet
        if(!InternetGetConnectedState(&dwTemp, 0))
            nError = GetLastError();
    
        // Initiate the connection to the internet
        if(nError == ERROR_SUCCESS)
        {
            pStream.Base.Http.hInternet = InternetOpen(_T("StormLib HTTP MPQ reader"),
                                                        INTERNET_OPEN_TYPE_PRECONFIG,
                                                        null,
                                                        null,
                                                        0);
            if(pStream.Base.Http.hInternet is null)
                nError = GetLastError();
        }
    
        // Connect to the server
        if(nError == ERROR_SUCCESS)
        {
            string szServerName;
            DWORD dwFlags = INTERNET_FLAG_KEEP_CONNECTION | INTERNET_FLAG_NO_UI | INTERNET_FLAG_NO_CACHE_WRITE;
    
            // Initiate connection with the server
            szFileName = BaseHttp_ExtractServerName(szFileName, szServerName);
            pStream.Base.Http.hConnect = InternetConnect(pStream.Base.Http.hInternet,
                                                          szServerName.toStringz,
                                                          INTERNET_DEFAULT_HTTP_PORT,
                                                          null,
                                                          null,
                                                          INTERNET_SERVICE_HTTP,
                                                          dwFlags,
                                                          0);
            if(pStream.Base.Http.hConnect is null)
                nError = GetLastError();
        }
    
        // Now try to query the file size
        if(nError == ERROR_SUCCESS)
        {
            // Open HTTP request to the file
            hRequest = HttpOpenRequest(pStream.Base.Http.hConnect, "GET".toStringz, szFileName.toStringz, null, null, null, INTERNET_FLAG_NO_CACHE_WRITE, 0);
            if(hRequest !is null)
            {
                if(HttpSendRequest(hRequest, null, 0, null, 0))
                {
                    ULONGLONG FileTime = 0;
                    DWORD dwFileSize = 0;
                    DWORD dwDataSize;
                    DWORD dwIndex = 0;
    
                    // Check if the MPQ has Last Modified field
                    dwDataSize = cast(DWORD)ULONGLONG.sizeof;
                    if(HttpQueryInfo(hRequest, HTTP_QUERY_LAST_MODIFIED | HTTP_QUERY_FLAG_SYSTEMTIME, &FileTime, &dwDataSize, &dwIndex))
                        pStream.Base.Http.FileTime = FileTime;
    
                    // Verify if the server supports random access
                    dwDataSize = cast(DWORD)DWORD.sizeof;
                    if(HttpQueryInfo(hRequest, HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER, &dwFileSize, &dwDataSize, &dwIndex))
                    {
                        if(dwFileSize != 0)
                        {
                            pStream.Base.Http.FileSize = dwFileSize;
                            pStream.Base.Http.FilePos = 0;
                            bFileAvailable = true;
                        }
                    }
                }
                InternetCloseHandle(hRequest);
            }
        }
    
        // If the file is not there and is not available for random access,
        // report error
        if(bFileAvailable == false)
        {
            pStream.BaseClose(pStream);
            return false;
        }
    
        return true;
    
    }
    else
    {
        // Not supported
        SetLastError(ERROR_NOT_SUPPORTED);
        pStream = pStream;
        return false;
    }
}

bool BaseHttp_Read(
    TFileStream pStream,                     // Pointer to an open stream
    ulong * pByteOffset,                     // Pointer to file byte offset. If null, it reads from the current position
    ubyte[] pbBuffer)                        // Pointer to data to be read
{
    version(Windows)
    {
        ULONGLONG ByteOffset = (pByteOffset !is null) ? *pByteOffset : pStream.Base.Http.FilePos;
        DWORD dwTotalBytesRead = 0;
    
        // Do we have to read anything at all?
        if(pbBuffer.length != 0)
        {
            HINTERNET hRequest;
            LPCTSTR szFileName;
            char[0x80] szRangeRequest;
            DWORD dwStartOffset = cast(DWORD)ByteOffset;
            DWORD dwEndOffset = dwStartOffset + pbBuffer.length;
    
            // Open HTTP request to the file
            szFileName = BaseHttp_ExtractServerName(pStream.szFileName, "");
            hRequest = HttpOpenRequest(pStream.Base.Http.hConnect, "GET".toStringz, szFileName.toStringz, null, null, null, INTERNET_FLAG_NO_CACHE_WRITE, 0);
            if(hRequest !is null)
            {
                // Add range request to the HTTP headers
                // http://www.clevercomponents.com/articles/article015/resuming.asp
                _stprintf(szRangeRequest, "Range: bytes=%u-%u".toStringz, cast(uint)dwStartOffset, cast(uint)dwEndOffset);
                HttpAddRequestHeaders(hRequest, szRangeRequest.ptr, 0xFFFFFFFF, HTTP_ADDREQ_FLAG_ADD_IF_NEW); 
    
                // Send the request to the server
                if(HttpSendRequest(hRequest, null, 0, null, 0))
                {
                    while(dwTotalBytesRead < pbBuffer.length)
                    {
                        DWORD dwBlockBytesToRead = pbBuffer.length - dwTotalBytesRead;
                        DWORD dwBlockBytesRead = 0;
    
                        // Read the block from the file
                        if(dwBlockBytesToRead > 0x200)
                            dwBlockBytesToRead = 0x200;
                        InternetReadFile(hRequest, pbBuffer, dwBlockBytesToRead, &dwBlockBytesRead);
    
                        // Check for end
                        if(dwBlockBytesRead == 0)
                            break;
    
                        // Move buffers
                        dwTotalBytesRead += dwBlockBytesRead;
                        pbBuffer += dwBlockBytesRead;
                    }
                }
                InternetCloseHandle(hRequest);
            }
        }
    
        // Increment the current file position by number of bytes read
        pStream.Base.Http.FilePos = ByteOffset + dwTotalBytesRead;
    
        // If the number of bytes read doesn't match the required amount, return false
        if(dwTotalBytesRead != pbBuffer.length)
            SetLastError(ERROR_HANDLE_EOF);
        return (dwTotalBytesRead == pbBuffer.length);
    }
    else
    {
        // Not supported
        SetLastError(ERROR_NOT_SUPPORTED);
        return false;
    }
}

void BaseHttp_Close(TFileStream pStream)
{
    version(Windows)
    {
        if(pStream.Base.Http.hConnect !is null)
            InternetCloseHandle(pStream.Base.Http.hConnect);
        pStream.Base.Http.hConnect = null;
    
        if(pStream.Base.Http.hInternet !is null)
            InternetCloseHandle(pStream.Base.Http.hInternet);
        pStream.Base.Http.hInternet = null;
    }
    else
    {
        pStream = pStream;
    }
}

// Initializes base functions for the mapped file
void BaseHttp_Init(TFileStream pStream)
{
    // Supply the stream functions
    pStream.BaseOpen    = &BaseHttp_Open;
    pStream.BaseRead    = &BaseHttp_Read;
    pStream.BaseGetSize = &BaseFile_GetSize;    // Reuse BaseFile function
    pStream.BaseGetPos  = &BaseFile_GetPos;     // Reuse BaseFile function
    pStream.BaseClose   = &BaseHttp_Close;

    // HTTP files are read-only
    pStream.dwFlags |= STREAM_FLAG_READ_ONLY;
}

//-----------------------------------------------------------------------------
// Local functions - flat stream support

uint FlatStream_CheckFile(TBlockStream pStream)
{
    ubyte[] FileBitmap = pStream.FileBitmap;
    uint WholeByteCount = pStream.BlockCount / 8;
    uint ExtraBitsCount = pStream.BlockCount & 7;
    ubyte ExpectedValue;

    // Verify the whole bytes - their value must be 0xFF
    for(uint i = 0; i < WholeByteCount; i++)
    {
        if(FileBitmap[i] != 0xFF)
            return 0;
    }

    // If there are extra bits, calculate the mask
    if(ExtraBitsCount != 0)
    {
        ExpectedValue = cast(ubyte)((1 << ExtraBitsCount) - 1);
        if(FileBitmap[WholeByteCount] != ExpectedValue)
            return 0;
    }

    // Yes, the file is complete
    return 1;
}

bool FlatStream_LoadBitmap(TBlockStream pStream)
{
    FILE_BITMAP_FOOTER Footer;
    ulong ByteOffset; 
    ubyte[] FileBitmap;
    uint BlockCount;
    uint BitmapSize;

    // Do not load the bitmap if we should not have to
    if(!(pStream.dwFlags & STREAM_FLAG_USE_BITMAP))
        return false;

    // Only if the size is greater than size of bitmap footer
    if(pStream.Base.File.FileSize > FILE_BITMAP_FOOTER.sizeof)
    {
        // Load the bitmap footer
        ByteOffset = pStream.Base.File.FileSize - FILE_BITMAP_FOOTER.sizeof;
        if(pStream.BaseRead(pStream, &ByteOffset, (cast(ubyte*)&Footer)[0 .. FILE_BITMAP_FOOTER.sizeof]))
        {
            // Make sure that the array is properly BSWAP-ed
            BSWAP_ARRAY32_UNSIGNED((cast(ubyte*)&Footer)[0 .. FILE_BITMAP_FOOTER.sizeof]);

            // Verify if there is actually a footer
            if(Footer.Signature == ID_FILE_BITMAP_FOOTER && Footer.Version == 0x03)
            {
                // Get the offset of the bitmap, number of blocks and size of the bitmap
                ByteOffset = MAKE_OFFSET64(Footer.MapOffsetHi, Footer.MapOffsetLo);
                BlockCount = cast(uint)(((ByteOffset - 1) / Footer.BlockSize) + 1);
                BitmapSize = (BlockCount + 7) / 8;

                // Check if the sizes match
                if(ByteOffset + BitmapSize + FILE_BITMAP_FOOTER.sizeof == pStream.Base.File.FileSize)
                {
                    // Allocate space for the bitmap
                    FileBitmap = new ubyte[BitmapSize];
                    if(FileBitmap !is null)
                    {
                        // Load the bitmap bits
                        if(!pStream.BaseRead(pStream, &ByteOffset, FileBitmap))
                        {
                            return false;
                        }

                        // Update the stream size
                        pStream.BuildNumber = Footer.BuildNumber;
                        pStream.StreamSize = ByteOffset;

                        // Fill the bitmap information
                        pStream.FileBitmap = FileBitmap;
                        pStream.BitmapSize = BitmapSize;
                        pStream.BlockSize  = Footer.BlockSize;
                        pStream.BlockCount = BlockCount;
                        pStream.IsComplete = FlatStream_CheckFile(pStream);
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

void FlatStream_UpdateBitmap(
    TBlockStream pStream,                // Pointer to an open stream
    ulong StartOffset,
    ulong EndOffset)
{
    ubyte[] FileBitmap = pStream.FileBitmap;
    uint BlockIndex;
    uint BlockSize = pStream.BlockSize;
    uint ByteIndex;
    ubyte BitMask;

    // Sanity checks
    assert((StartOffset & (BlockSize - 1)) == 0);
    assert(FileBitmap !is null);

    // Calculate the index of the block
    BlockIndex = cast(uint)(StartOffset / BlockSize);
    ByteIndex = BlockIndex / 0x08;
    BitMask = cast(ubyte)(1 << (BlockIndex & 0x07));

    // Set all bits for the specified range
    while(StartOffset < EndOffset)
    {
        // Set the bit
        FileBitmap[ByteIndex] |= BitMask;

        // Move all
        StartOffset += BlockSize;
        ByteIndex += (BitMask >> 0x07);
        BitMask = cast(ubyte)((BitMask >> 0x07) | (BitMask << 0x01));
    }

    // Increment the bitmap update count
    pStream.IsModified = 1;
}

bool FlatStream_BlockCheck(
    TBlockStream pStream,                // Pointer to an open stream
    ulong BlockOffset)
{
    ubyte[] FileBitmap = pStream.FileBitmap;
    uint BlockIndex;
    ubyte BitMask;

    // Sanity checks
    assert((BlockOffset & (pStream.BlockSize - 1)) == 0);
    assert(FileBitmap !is null);
    
    // Calculate the index of the block
    BlockIndex = cast(uint)(BlockOffset / pStream.BlockSize);
    BitMask = cast(ubyte)(1 << (BlockIndex & 0x07));

    // Check if the bit is present
    return (FileBitmap[BlockIndex / 0x08] & BitMask) ? true : false;
}

bool FlatStream_BlockRead(
    TBlockStream pStream,                // Pointer to an open stream
    ulong StartOffset,
    ulong EndOffset,
    ubyte[] BlockBuffer,
    bool bAvailable)
{
    uint BytesToRead = cast(uint)(EndOffset - StartOffset);

    // The starting offset must be aligned to size of the block
    assert(pStream.FileBitmap !is null);
    assert((StartOffset & (pStream.BlockSize - 1)) == 0);
    assert(StartOffset < EndOffset);

    // If the blocks are not available, we need to load them from the master
    // and then save to the mirror
    if(bAvailable == false)
    {
        // If we have no master, we cannot satisfy read request
        if(pStream.pMaster is null)
            return false;

        // Load the blocks from the master stream
        // Note that we always have to read complete blocks
        // so they get properly stored to the mirror stream
        if(!FileStream_Read(pStream.pMaster, &StartOffset, BlockBuffer[0..BytesToRead]))
            return false;

        // Store the loaded blocks to the mirror file.
        // Note that this operation is not required to succeed
        if(pStream.BaseWrite(pStream, &StartOffset, BlockBuffer[0..BytesToRead]))
            FlatStream_UpdateBitmap(pStream, StartOffset, EndOffset);

        return true;
    }
    else
    {
        if(BytesToRead > BlockBuffer.length)
            BytesToRead = cast(uint)BlockBuffer.length;
        return pStream.BaseRead(pStream, &StartOffset, BlockBuffer[0..BytesToRead]);
    }
}

void FlatStream_Close(TBlockStream pStream)
{
    FILE_BITMAP_FOOTER Footer;

    if(pStream.FileBitmap && pStream.IsModified)
    {
        // Write the file bitmap
        pStream.BaseWrite(pStream, &pStream.StreamSize, pStream.FileBitmap);
        
        // Prepare and write the file footer
        Footer.Signature   = ID_FILE_BITMAP_FOOTER;
        Footer.Version     = 3;
        Footer.BuildNumber = pStream.BuildNumber;
        Footer.MapOffsetLo = cast(uint)(pStream.StreamSize & 0xFFFFFFFF);
        Footer.MapOffsetHi = cast(uint)(pStream.StreamSize >> 0x20);
        Footer.BlockSize   = pStream.BlockSize;
        
        BSWAP_ARRAY32_UNSIGNED((cast(ubyte*)&Footer)[0..FILE_BITMAP_FOOTER.sizeof]);
        pStream.BaseWrite(pStream, null, (cast(ubyte*)&Footer)[0..FILE_BITMAP_FOOTER.sizeof]);
    }

    // Close the base class
    BlockStream_Close(pStream);
}

bool FlatStream_CreateMirror(TBlockStream pStream)
{
    ulong MasterSize = 0;
    ulong MirrorSize = 0;
    ubyte[] FileBitmap;
    uint dwBitmapSize;
    uint dwBlockCount;
    bool bNeedCreateMirrorStream = true;
    bool bNeedResizeMirrorStream = true;

    // Do we have master function and base creation function?
    if(pStream.pMaster is null || pStream.BaseCreate is null)
        return false;

    // Retrieve the master file size, block count and bitmap size
    FileStream_GetSize(pStream.pMaster, MasterSize);
    dwBlockCount = cast(uint)((MasterSize + DEFAULT_BLOCK_SIZE - 1) / DEFAULT_BLOCK_SIZE);
    dwBitmapSize = cast(uint)((dwBlockCount + 7) / 8);

    // Setup stream size and position
    pStream.BuildNumber = DEFAULT_BUILD_NUMBER;        // BUGBUG: Really???
    pStream.StreamSize = MasterSize;
    pStream.StreamPos = 0;

    // Open the base stream for write access
    if(pStream.BaseOpen(pStream, pStream.szFileName, 0))
    {
        // If the file open succeeded, check if the file size matches required size
        pStream.BaseGetSize(pStream, MirrorSize);
        if(MirrorSize == MasterSize + dwBitmapSize + FILE_BITMAP_FOOTER.sizeof)
        {
            // Attempt to load an existing file bitmap
            if(FlatStream_LoadBitmap(pStream))
                return true;

            // We need to create new file bitmap
            bNeedResizeMirrorStream = false;
        }

        // We need to create mirror stream
        bNeedCreateMirrorStream = false;
    }

    // Create a new stream, if needed
    if(bNeedCreateMirrorStream)
    {
        if(!pStream.BaseCreate(pStream))
            return false;
    }

    // If we need to, then resize the mirror stream
    if(bNeedResizeMirrorStream)
    {
        if(!pStream.BaseResize(pStream, MasterSize + dwBitmapSize + FILE_BITMAP_FOOTER.sizeof))
            return false;
    }

    // Allocate the bitmap array
    FileBitmap = new ubyte[dwBitmapSize];

    // Initialize the bitmap
    pStream.FileBitmap = FileBitmap;
    pStream.BitmapSize = dwBitmapSize;
    pStream.BlockSize  = DEFAULT_BLOCK_SIZE;
    pStream.BlockCount = dwBlockCount;
    pStream.IsComplete = 0;
    pStream.IsModified = 1;

    // Note: Don't write the stream bitmap right away.
    // Doing so would cause sparse file resize on NTFS,
    // which would take long time on larger files.
    return true;
}

TFileStream FlatStream_Open(string szFileName, uint dwStreamFlags)
{
    TBlockStream  pStream;    
    ulong ByteOffset = 0;

    // Create new empty stream
    pStream = AllocateFileStream!TBlockStream(szFileName, dwStreamFlags);
    if(pStream is null)
        return null;

    // Do we have a master stream?
    if(pStream.pMaster !is null)
    {
        if(!FlatStream_CreateMirror(pStream))
        {
            FileStream_Close(pStream);
            SetLastError(ERROR_FILE_NOT_FOUND);
            return null;
        }
    }
    else
    {
        // Attempt to open the base stream
        if(!pStream.BaseOpen(pStream, pStream.szFileName, dwStreamFlags))
            return null;

        // Load the bitmap, if required to
        if(dwStreamFlags & STREAM_FLAG_USE_BITMAP)
            FlatStream_LoadBitmap(pStream);
    }

    // If we have a stream bitmap, set the reading functions
    // which check presence of each file block
    if(pStream.FileBitmap !is null)
    {
        // Set the stream position to zero. Stream size is already set
        assert(pStream.StreamSize != 0);
        pStream.StreamPos = 0;
        pStream.dwFlags |= STREAM_FLAG_READ_ONLY;

        // Supply the stream functions
        pStream.StreamRead    = cast(STREAM_READ)&BlockStream_Read;
        pStream.StreamGetSize = &BlockStream_GetSize;
        pStream.StreamGetPos  = &BlockStream_GetPos;
        pStream.StreamClose   = cast(STREAM_CLOSE)&FlatStream_Close;

        // Supply the block functions
        pStream.BlockCheck    = cast(BLOCK_CHECK)&FlatStream_BlockCheck;
        pStream.BlockRead     = cast(BLOCK_READ)&FlatStream_BlockRead;
    }
    else
    {
        // Reset the base position to zero
        pStream.BaseRead(pStream, &ByteOffset, null);

        // Setup stream size and position
        pStream.StreamSize = pStream.Base.File.FileSize;
        pStream.StreamPos = 0;

        // Set the base functions
        pStream.StreamRead    = pStream.BaseRead;
        pStream.StreamWrite   = pStream.BaseWrite;
        pStream.StreamResize  = pStream.BaseResize;
        pStream.StreamGetSize = pStream.BaseGetSize;
        pStream.StreamGetPos  = pStream.BaseGetPos;
        pStream.StreamClose   = pStream.BaseClose;
    }

    return pStream;
}

//-----------------------------------------------------------------------------
// Local functions - partial stream support

bool IsPartHeader(ref PART_FILE_HEADER pPartHdr)
{
    bool isdigit(dchar c)
    {
        return '0' <= c && c <= '9'; 
    }
    
    // Version number must be 2
    if(pPartHdr.PartialVersion == 2)
    {
        // GameBuildNumber must be an ASCII number
        if(isdigit(pPartHdr.GameBuildNumber[0]) && isdigit(pPartHdr.GameBuildNumber[1]) && isdigit(pPartHdr.GameBuildNumber[2]))
        {
            // Block size must be power of 2
            if((pPartHdr.BlockSize & (pPartHdr.BlockSize - 1)) == 0)
                return true;
        }
    }

    return false;
}

uint PartStream_CheckFile(TBlockStream pStream)
{
    PART_FILE_MAP_ENTRY[] FileBitmap = cast(PART_FILE_MAP_ENTRY[])pStream.FileBitmap;
    size_t dwBlockCount;

    // Get the number of blocks
    dwBlockCount = cast(size_t)((pStream.StreamSize + pStream.BlockSize - 1) / pStream.BlockSize);
    assert(FileBitmap.length == dwBlockCount);
    
    // Check all blocks
    foreach(ref block; FileBitmap)
    {
        // Few sanity checks
        assert(block.LargeValueHi == 0);
        assert(block.LargeValueLo == 0);
        assert(block.Flags == 0 || block.Flags == 3);

        // Check if this block is present
        if(block.Flags != 3)
            return 0;
    }

    // Yes, the file is complete
    return 1;
}

bool PartStream_LoadBitmap(TBlockStream pStream)
{
    PART_FILE_MAP_ENTRY[] FileBitmap;
    PART_FILE_HEADER PartHdr;
    ulong ByteOffset = 0;
    ulong StreamSize = 0;
    uint BlockCount;
    uint BitmapSize;

    // Only if the size is greater than size of the bitmap header
    if(pStream.Base.File.FileSize > PART_FILE_HEADER.sizeof)
    {
        // Attempt to read PART file header
        if(pStream.BaseRead(pStream, &ByteOffset, (cast(ubyte*)&PartHdr)[0 .. PART_FILE_HEADER.sizeof]))
        {
            // We need to swap PART file header on big-endian platforms
            BSWAP_ARRAY32_UNSIGNED((cast(ubyte*)&PartHdr)[0 .. PART_FILE_HEADER.sizeof]);

            // Verify the PART file header
            if(IsPartHeader(PartHdr))
            {
                // Get the number of blocks and size of one block
                StreamSize = MAKE_OFFSET64(PartHdr.FileSizeHi, PartHdr.FileSizeLo);
                ByteOffset = PART_FILE_HEADER.sizeof;
                BlockCount = cast(uint)((StreamSize + PartHdr.BlockSize - 1) / PartHdr.BlockSize);
                BitmapSize = cast(uint)(BlockCount * PART_FILE_MAP_ENTRY.sizeof);

                // Check if sizes match
                if((ByteOffset + BitmapSize) < pStream.Base.File.FileSize)
                {
                    // Allocate space for the array of PART_FILE_MAP_ENTRY
                    FileBitmap = new PART_FILE_MAP_ENTRY[cast(size_t)BlockCount];
                    if(FileBitmap !is null)
                    {
                        // Load the block map
                        if(!pStream.BaseRead(pStream, &ByteOffset, cast(ubyte[])FileBitmap))
                        {
                            return false;
                        }

                        // Make sure that the byte order is correct
                        BSWAP_ARRAY32_UNSIGNED((cast(ubyte*)FileBitmap.ptr)[0 .. BitmapSize]);

                        // Update the stream size
                        pStream.BuildNumber = PartHdr.GameBuildNumber.to!uint;
                        pStream.StreamSize = StreamSize;

                        // Fill the bitmap information
                        pStream.FileBitmap = cast(ubyte[])FileBitmap;
                        pStream.BitmapSize = BitmapSize;
                        pStream.BlockSize  = PartHdr.BlockSize;
                        pStream.BlockCount = BlockCount;
                        pStream.IsComplete = PartStream_CheckFile(pStream);
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

void PartStream_UpdateBitmap(
    TBlockStream pStream,                // Pointer to an open stream
    ulong StartOffset,
    ulong EndOffset,
    ulong RealOffset)
{
    PART_FILE_MAP_ENTRY* FileBitmap;
    uint BlockSize = pStream.BlockSize;

    // Sanity checks
    assert((StartOffset & (BlockSize - 1)) == 0);
    assert(pStream.FileBitmap !is null);

    // Calculate the first entry in the block map
    FileBitmap = cast(PART_FILE_MAP_ENTRY*)pStream.FileBitmap.ptr + cast(size_t)(StartOffset / BlockSize);

    // Set all bits for the specified range
    while(StartOffset < EndOffset)
    {
        // Set the bit
        FileBitmap.BlockOffsHi = cast(uint)(RealOffset >> 0x20);
        FileBitmap.BlockOffsLo = cast(uint)(RealOffset & 0xFFFFFFFF);
        FileBitmap.Flags = 3;

        // Move all
        StartOffset += BlockSize;
        RealOffset += BlockSize;
        FileBitmap++;
    }

    // Increment the bitmap update count
    pStream.IsModified = 1;
}

bool PartStream_BlockCheck(
    TBlockStream pStream,                // Pointer to an open stream
    ulong BlockOffset)
{
    PART_FILE_MAP_ENTRY* FileBitmap;

    // Sanity checks
    assert((BlockOffset & (pStream.BlockSize - 1)) == 0);
    assert(pStream.FileBitmap !is null);
    
    // Calculate the block map entry
    FileBitmap = cast(PART_FILE_MAP_ENTRY*)pStream.FileBitmap.ptr + cast(size_t)(BlockOffset / pStream.BlockSize);

    // Check if the flags are present
    return (FileBitmap.Flags & 0x03) ? true : false;
}

bool PartStream_BlockRead(
    TBlockStream pStream,
    ulong StartOffset,
    ulong EndOffset,
    ubyte[] BlockBuffer,
    bool bAvailable)
{
    PART_FILE_MAP_ENTRY* FileBitmap;
    ulong ByteOffset;
    size_t BytesToRead;
    uint BlockIndex = cast(uint)(StartOffset / pStream.BlockSize);

    // The starting offset must be aligned to size of the block
    assert(pStream.FileBitmap !is null);
    assert((StartOffset & (pStream.BlockSize - 1)) == 0);
    assert(StartOffset < EndOffset);

    // If the blocks are not available, we need to load them from the master
    // and then save to the mirror
    if(bAvailable == false)
    {
        // If we have no master, we cannot satisfy read request
        if(pStream.pMaster is null)
            return false;

        // Load the blocks from the master stream
        // Note that we always have to read complete blocks
        // so they get properly stored to the mirror stream
        BytesToRead = cast(size_t)(EndOffset - StartOffset);
        if(!FileStream_Read(pStream.pMaster, &StartOffset, BlockBuffer[0 .. BytesToRead]))
            return false;

        // The loaded blocks are going to be stored to the end of the file
        // Note that this operation is not required to succeed
        if(pStream.BaseGetSize(pStream, ByteOffset))
        {
            // Store the loaded blocks to the mirror file.
            if(pStream.BaseWrite(pStream, &ByteOffset, BlockBuffer[0 .. BytesToRead]))
            {
                PartStream_UpdateBitmap(pStream, StartOffset, EndOffset, ByteOffset);
            }
        }
    }
    else
    {
        // Get the file map entry
        FileBitmap = cast(PART_FILE_MAP_ENTRY*)pStream.FileBitmap.ptr + cast(size_t)BlockIndex;

        // Read all blocks
        while(StartOffset < EndOffset)
        {
            // Get the number of bytes to be read
            BytesToRead = cast(uint)(EndOffset - StartOffset);
            if(BytesToRead > pStream.BlockSize)
                BytesToRead = pStream.BlockSize;
            if(BytesToRead > BlockBuffer.length)
                BytesToRead = BlockBuffer.length;

            // Read the block
            ByteOffset = MAKE_OFFSET64(FileBitmap.BlockOffsHi, FileBitmap.BlockOffsLo);
            if(!pStream.BaseRead(pStream, &ByteOffset, BlockBuffer[0..BytesToRead]))
                return false;

            // Move the pointers
            StartOffset += pStream.BlockSize;
            BlockBuffer = BlockBuffer[pStream.BlockSize .. $];
            FileBitmap++;
        }
    }

    return true;
}

void PartStream_Close(TBlockStream pStream)
{
    PART_FILE_HEADER PartHeader;
    ulong ByteOffset = 0;

    if(pStream.FileBitmap && pStream.IsModified)
    {
        // Prepare the part file header
        PartHeader.PartialVersion = 2;
        PartHeader.FileSizeHi     = cast(uint)(pStream.StreamSize >> 0x20);
        PartHeader.FileSizeLo     = cast(uint)(pStream.StreamSize & 0xFFFFFFFF);
        PartHeader.BlockSize      = pStream.BlockSize;
        
        // Make sure that the header is properly BSWAPed
        BSWAP_ARRAY32_UNSIGNED((cast(ubyte*)&PartHeader)[0 .. PART_FILE_HEADER.sizeof]);
        sprintf(PartHeader.GameBuildNumber.ptr, "%u", cast(uint)pStream.BuildNumber);

        // Write the part header
        pStream.BaseWrite(pStream, &ByteOffset, (cast(ubyte*)&PartHeader)[0 .. PART_FILE_HEADER.sizeof]);

        // Write the block bitmap
        BSWAP_ARRAY32_UNSIGNED(pStream.FileBitmap);
        pStream.BaseWrite(pStream, null, pStream.FileBitmap);
    }

    // Close the base class
    BlockStream_Close(pStream);
}

bool PartStream_CreateMirror(TBlockStream pStream)
{
    ulong RemainingSize;
    ulong MasterSize = 0;
    ulong MirrorSize = 0;
    ubyte[] FileBitmap;
    uint dwBitmapSize;
    uint dwBlockCount;
    bool bNeedCreateMirrorStream = true;
    bool bNeedResizeMirrorStream = true;

    // Do we have master function and base creation function?
    if(pStream.pMaster is null || pStream.BaseCreate is null)
        return false;

    // Retrieve the master file size, block count and bitmap size
    FileStream_GetSize(pStream.pMaster, MasterSize);
    dwBlockCount = cast(uint)((MasterSize + DEFAULT_BLOCK_SIZE - 1) / DEFAULT_BLOCK_SIZE);
    dwBitmapSize = cast(uint)(dwBlockCount * PART_FILE_MAP_ENTRY.sizeof);

    // Setup stream size and position
    pStream.BuildNumber = DEFAULT_BUILD_NUMBER;        // BUGBUG: Really???
    pStream.StreamSize = MasterSize;
    pStream.StreamPos = 0;

    // Open the base stream for write access
    if(pStream.BaseOpen(pStream, pStream.szFileName, 0))
    {
        // If the file open succeeded, check if the file size matches required size
        pStream.BaseGetSize(pStream, MirrorSize);
        if(MirrorSize >= PART_FILE_HEADER.sizeof + dwBitmapSize)
        {
            // Check if the remaining size is aligned to block
            RemainingSize = MirrorSize - PART_FILE_HEADER.sizeof - dwBitmapSize;
            if((RemainingSize & (DEFAULT_BLOCK_SIZE - 1)) == 0 || RemainingSize == MasterSize)
            {
                // Attempt to load an existing file bitmap
                if(PartStream_LoadBitmap(pStream))
                    return true;
            }
        }

        // We need to create mirror stream
        bNeedCreateMirrorStream = false;
    }

    // Create a new stream, if needed
    if(bNeedCreateMirrorStream)
    {
        if(!pStream.BaseCreate(pStream))
            return false;
    }

    // If we need to, then resize the mirror stream
    if(bNeedResizeMirrorStream)
    {
        if(!pStream.BaseResize(pStream, PART_FILE_HEADER.sizeof + dwBitmapSize))
            return false;
    }

    // Allocate the bitmap array
    FileBitmap = new ubyte[dwBitmapSize];
    if(FileBitmap is null)
        return false;

    // Initialize the bitmap
    pStream.FileBitmap = FileBitmap;
    pStream.BitmapSize = dwBitmapSize;
    pStream.BlockSize  = DEFAULT_BLOCK_SIZE;
    pStream.BlockCount = dwBlockCount;
    pStream.IsComplete = 0;
    pStream.IsModified = 1;

    // Note: Don't write the stream bitmap right away.
    // Doing so would cause sparse file resize on NTFS,
    // which would take long time on larger files.
    return true;
}


TFileStream PartStream_Open(string szFileName, uint dwStreamFlags)
{
    TBlockStream pStream;

    // Create new empty stream
    pStream = AllocateFileStream!TBlockStream(szFileName, dwStreamFlags);
    if(pStream is null)
        return null;

    // Do we have a master stream?
    if(pStream.pMaster !is null)
    {
        if(!PartStream_CreateMirror(pStream))
        {
            FileStream_Close(pStream);
            SetLastError(ERROR_FILE_NOT_FOUND);
            return null;
        }
    }
    else
    {
        // Attempt to open the base stream
        if(!pStream.BaseOpen(pStream, pStream.szFileName, dwStreamFlags))
        {
            FileStream_Close(pStream);
            return null;
        }

        // Load the part stream block map
        if(!PartStream_LoadBitmap(pStream))
        {
            FileStream_Close(pStream);
            SetLastError(ERROR_BAD_FORMAT);
            return null;
        }
    }

    // Set the stream position to zero. Stream size is already set
    assert(pStream.StreamSize != 0);
    pStream.StreamPos = 0;
    pStream.dwFlags |= STREAM_FLAG_READ_ONLY;

    // Set new function pointers
    pStream.StreamRead    = cast(STREAM_READ)&BlockStream_Read;
    pStream.StreamGetPos  = &BlockStream_GetPos;
    pStream.StreamGetSize = &BlockStream_GetSize;
    pStream.StreamClose   = cast(STREAM_CLOSE)&PartStream_Close;

    // Supply the block functions
    pStream.BlockCheck    = cast(BLOCK_CHECK)&PartStream_BlockCheck;
    pStream.BlockRead     = cast(BLOCK_READ)&PartStream_BlockRead;
    return pStream;
}

//-----------------------------------------------------------------------------
// File stream allocation function

static STREAM_INIT StreamBaseInit[4] =
[
    &BaseFile_Init,
    &BaseMap_Init, 
    &BaseHttp_Init,
    &BaseNone_Init
];

/**
*   This function allocates an empty structure for the file stream
*   The stream structure is created as flat block, variable length
*   The file name is placed after the end of the stream structure data
*/
T AllocateFileStream(T)(
    string szFileName,
    uint dwStreamFlags)
    if(is(T : TFileStream))
{
    TFileStream pMaster = null;
    T pStream = null;

    // The caller can specify chain of files in the following form:
    // C:\archive.MPQ*http://www.server.com/MPQs/archive-server.MPQ
    // In that case, we use the part after "*" as master file name
    auto spl = szFileName.splitter('*').array;
    
    // Don't allow another master file in the string
    if(spl.length > 3)
    {
        SetLastError(ERROR_INVALID_PARAMETER);
        return null;
    }
    // If we have a next file, we need to open it as master stream
    // Note that we don't care if the master stream exists or not,
    // If it doesn't, later attempts to read missing file block will fail
    else if(spl.length == 3)
    {
        // Open the master file
        pMaster = FileStream_OpenFile(spl[2], STREAM_FLAG_READ_ONLY);
    }
    
    // Allocate the stream structure for the given stream type
    pStream = new T();
    if(pStream !is null)
    {
        pStream.pMaster = pMaster;
        pStream.dwFlags = dwStreamFlags;
        
        // Initialize the file name
        pStream.szFileName = szFileName;

        // Initialize the stream functions
        StreamBaseInit[dwStreamFlags & 0x03](pStream);
    }

    return pStream;
}
// ensure of std behavior
unittest
{
    assert(splitter("C:\archive.MPQ*http://www.server.com/MPQs/archive-server.MPQ", '*').equal(["C:\archive.MPQ", "", "http://www.server.com/MPQs/archive-server.MPQ"]));
    assert(splitter("C:\archive.MPQ", '*').equal(["C:\archive.MPQ"]));
}