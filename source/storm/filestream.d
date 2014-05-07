/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.filestream;

import storm.callback;
import storm.constants;
import storm.errors;

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
    pStream = AllocateFileStream(szFileName, dwStreamFlags);
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
    void * FileBitmap;                      // Array of bits for file blocks
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
TFileStream AllocateFileStream(
    string szFileName,
    uint dwStreamFlags)
{
    TFileStream pMaster = null;
    TFileStream pStream = null;

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
    pStream = new TFileStream;
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