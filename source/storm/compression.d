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
int    WINAPI SCompImplode    (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int cbInBuffer);
int    WINAPI SCompExplode    (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int cbInBuffer);
int    WINAPI SCompCompress   (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int cbInBuffer, unsigned uCompressionMask, int nCmpType, int nCmpLevel);
int    WINAPI SCompDecompress (void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int cbInBuffer);
int    WINAPI SCompDecompress2(void * pvOutBuffer, int * pcbOutBuffer, void * pvInBuffer, int cbInBuffer);
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

