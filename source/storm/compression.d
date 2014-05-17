/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, Daniel Chiamarello <dchiamarello@madvawes.com>, NCrashed <ncrashed@gmail.com>
*/
// Original header
/*****************************************************************************/
/* SCompression.cpp                       Copyright (c) Ladislav Zezula 2003 */
/*---------------------------------------------------------------------------*/
/* This module serves as a bridge between StormLib code and (de)compression  */
/* functions. All (de)compression calls go (and should only go) through this */   
/* module. No system headers should be included in this module to prevent    */
/* compile-time problems.                                                    */
/*---------------------------------------------------------------------------*/
/*   Date    Ver   Who  Comment                                              */
/* --------  ----  ---  -------                                              */
/* 01.04.03  1.00  Lad  The first version of SCompression.cpp                */
/* 19.11.03  1.01  Dan  Big endian handling                                  */
/*****************************************************************************/
module storm.compression;

/* Public interface to port
int    WINAPI SCompImplode    (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int inBuffer.length);
int    WINAPI SCompExplode    (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int inBuffer.length);
int    WINAPI SCompCompress   (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int inBuffer.length, unsigned uCompressionMask, int nCmpType, int nCmpLevel);
int    WINAPI SCompDecompress (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int inBuffer.length);
int    WINAPI SCompDecompress2(void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int inBuffer.length);
*/

private :

//-----------------------------------------------------------------------------
// Local structures

/// Information about the input and output buffers for pklib
struct TDataInfo
{
    ubyte* pbInBuff;                    // Pointer to input data buffer
    ubyte* pbInBuffEnd;                 // End of the input buffer
    ubyte* pbOutBuff;                   // Pointer to output data buffer
    ubyte* pbOutBuffEnd;                // End of the output buffer
}

/// Prototype of the compression function
/// Function doesn't return an error. A success means that the size of compressed buffer
/// is lower than size of uncompressed buffer.
alias void function(
    ubyte[] outBuffer,                  // [out] Pointer to the buffer where the compressed data will be stored
    out size_t cbOutBuffer,             // [out] Pointer to length of the buffer pointed by pvOutBuffer
    ubyte[] pvInBuffer,                 // [in]  Pointer to the buffer with data to compress
    ref int pCmpType,                   // [in]  Compression-method specific value. ADPCM Setups this for the following Huffman compression
    int nCmpLevel) COMPRESS;            // [in]  Compression specific value. ADPCM uses this. Should be set to zero.

/// Prototype of the decompression function
/// Returns true if success, false if failure
alias bool function(
    ubyte[] pvOutBuffer,                // [out] Pointer to the buffer where to store decompressed data
    out size_t outLength,               // [out] Pointer to total size of the buffer pointed by pvOutBuffer
                                        // [out] Contains length of the decompressed data
    ubyte[] pvInBuffer) DECOMPRESS;     // [in]  Pointer to data to be decompressed  

// Table of compression functions
struct TCompressTable
{
    uint uMask;                         // Compression mask
    COMPRESS Compress;                  // Compression function
}

// Table of decompression functions
struct TDecompressTable
{
    uint uMask;                         // Decompression bit
    DECOMPRESS    Decompress;           // Decompression function
}

/*****************************************************************************/
/*                                                                           */
/*  Support for Huffman compression (0x01)                                   */
/*                                                                           */
/*****************************************************************************/

import storm.huffman;

size_t compress_huff(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
{
    auto ht = new THuffmannTree(true);
    auto os = new TOutputStream(outBuffer);

    return ht.compress(os, inBuffer, pCmpType);
}                 

bool decompress_huff(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
{
    auto ht  = new THuffmannTree(false);
    auto _is = new TInputStream(inBuffer);

    outLength = ht.decompress(outBuffer, _is);
    return outLength != 0;
}

/******************************************************************************/
/*                                                                            */
/*  Support for ZLIB compression (0x02)                                       */
/*                                                                            */
/******************************************************************************/

import etc.c.zlib;

size_t compress_ZLIB(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
{
    z_stream z;                        // Stream information for zlib
    int windowBits;
    int nResult;

    // Fill the stream structure for zlib
    z.next_in   = cast(ubyte*)inBuffer.ptr;
    z.avail_in  = cast(uint)inBuffer.length;
    z.total_in  = inBuffer.length;
    z.next_out  = cast(ubyte*)outBuffer.ptr;
    z.avail_out = cast(uint)outBuffer.length;
    z.total_out = 0;
    z.zalloc    = null;
    z.zfree     = null;

    // Determine the proper window bits (WoW.exe build 12694)
    if(inBuffer.length <= 0x100)
        windowBits = 8;
    else if(inBuffer.length <= 0x200)
        windowBits = 9;
    else if(inBuffer.length <= 0x400)
        windowBits = 10;
    else if(inBuffer.length <= 0x800)
        windowBits = 11;
    else if(inBuffer.length <= 0x1000)
        windowBits = 12;
    else if(inBuffer.length <= 0x2000)
        windowBits = 13;
    else if(inBuffer.length <= 0x4000)
        windowBits = 14;
    else
        windowBits = 15;

    // Initialize the compression.
    // Storm.dll uses zlib version 1.1.3
    // Wow.exe uses zlib version 1.2.3
    nResult = deflateInit2(&z,
                            6,                  // Compression level used by WoW MPQs
                            Z_DEFLATED,
                            windowBits,
                            8,
                            Z_DEFAULT_STRATEGY);
    size_t total_out;
    if(nResult == Z_OK)
    {
        // Call zlib to compress the data
        nResult = deflate(&z, Z_FINISH);
        
        if(nResult == Z_OK || nResult == Z_STREAM_END)
            total_out = z.total_out;
            
        deflateEnd(&z);
    }
    return total_out;
}

bool Decompress_ZLIB(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
{
    z_stream z;                        // Stream information for zlib
    int nResult;

    // Fill the stream structure for zlib
    z.next_in   = cast(ubyte*)inBuffer.ptr;
    z.avail_in  = cast(uint)inBuffer.length;
    z.total_in  = inBuffer.length;
    z.next_out  = cast(ubyte*)outBuffer.ptr;
    z.avail_out = cast(uint)outBuffer.length;
    z.total_out = 0;
    z.zalloc    = null;
    z.zfree     = null;

    // Initialize the decompression structure. Storm.dll uses zlib version 1.1.3
    if((nResult = inflateInit(&z)) == 0)
    {
        // Call zlib to decompress the data
        nResult = inflate(&z, Z_FINISH);
        outLength = z.total_out;
        inflateEnd(&z);
    }
    return cast(bool)nResult;
}
