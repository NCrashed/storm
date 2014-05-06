/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.filestream;

import storm.callback;

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
    ulong* pByteOffset,                 // Pointer to file byte offset. If NULL, it reads from the current position
    ubyte[] pvBuffer                    // Pointer to data to be read
    );

alias STREAM_WRITE = bool function(
    TFileStream pStream,            // Pointer to an open stream
    ulong* pByteOffset,             // Pointer to file byte offset. If NULL, it writes to the current position
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
    struct File
    {
        ulong FileSize;                 // Size of the file
        ulong FilePos;                  // Current file position
        ulong FileTime;                 // Last write time
        void* hFile;                    // File handle
    } 

    struct Map
    {
        ulong FileSize;                 // Size of the file
        ulong FilePos;                  // Current file position
        ulong FileTime;                 // Last write time
        ubyte* pbFile;                  // Pointer to mapped view
    }

    struct Http
    {
        ulong FileSize;                 // Size of the file
        ulong FilePos;                  // Current file position
        ulong FileTime;                 // Last write time
        void* hInternet;                // Internet handle
        void* hConnect;                 // Connection to the internet server
    }
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
    TFileStream * pMaster;                  // Master stream (e.g. MPQ on a web server)
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