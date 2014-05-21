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

bool decompress_ZLIB(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
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

/******************************************************************************/
/*                                                                            */
/*  Support functions for PKWARE Data Compression Library compression (0x08)  */
/*                                                                            */
/******************************************************************************/

import storm.pklib.pklib;

/// Function loads data from the input buffer. Used by Pklib's "implode"
/// and "explode" function as user-defined callback
/// Returns number of bytes loaded
///    
///   char[] buf          - Pointer to a buffer where to store loaded data
///   void * param        - Custom pointer, parameter of implode/explode
uint readInputData(ubyte * buf, uint * size, void * param)
{
    TDataInfo * pInfo = cast(TDataInfo *)param;
    uint nMaxAvail = cast(uint)(pInfo.pbInBuffEnd - pInfo.pbInBuff);
    uint nToRead = *size;

    // Check the case when not enough data available
    if(nToRead > nMaxAvail)
        nToRead = nMaxAvail;
    
    // Load data and increment offsets
    buf[0 .. nToRead] = pInfo.pbInBuff[0 .. nToRead];
    pInfo.pbInBuff += nToRead;
    assert(pInfo.pbInBuff <= pInfo.pbInBuffEnd);
    return nToRead;
}

/// Function for store output data. Used by Pklib's "implode" and "explode"
/// as user-defined callback
///    
///   char * buf          - Pointer to data to be written
///   unsigned int * size - Number of bytes to write
///   void * param        - Custom pointer, parameter of implode/explode
void writeOutputData(ubyte * buf, uint * size, void * param)
{
    TDataInfo * pInfo = cast(TDataInfo *)param;
    uint nMaxWrite = cast(uint)(pInfo.pbOutBuffEnd - pInfo.pbOutBuff);
    uint nToWrite = *size;

    // Check the case when not enough space in the output buffer
    if(nToWrite > nMaxWrite)
        nToWrite = nMaxWrite;

    // Write output data and increments offsets
    pInfo.pbOutBuff[0 .. nToWrite] = buf[0 .. nToWrite];
    pInfo.pbOutBuff += nToWrite;
    assert(pInfo.pbOutBuff <= pInfo.pbOutBuffEnd);
}

size_t compress_PKLIB(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
{
    TDataInfo Info;                                      // Data information
    auto work_buf = new ubyte[CMP_BUFFER_SIZE];          // Pklib's work buffer
    uint dict_size;                                      // Dictionary size
    uint ctype = CMP_BINARY;                             // Compression type


    // Fill data information structure
    Info.pbInBuff     = cast(ubyte*)inBuffer.ptr;
    Info.pbInBuffEnd  = cast(ubyte*)&inBuffer[$];
    Info.pbOutBuff    = cast(ubyte*)outBuffer.ptr;
    Info.pbOutBuffEnd = cast(ubyte*)&outBuffer[$];

    //
    // Set the dictionary size
    //
    // Diablo I uses fixed dictionary size of CMP_IMPLODE_DICT_SIZE3
    // Starcraft I uses the variable dictionary size based on algorithm below
    //

    if (inBuffer.length < 0x600)
        dict_size = CMP_IMPLODE_DICT_SIZE1;
    else if(0x600 <= inBuffer.length && inBuffer.length < 0xC00)
        dict_size = CMP_IMPLODE_DICT_SIZE2;
    else
        dict_size = CMP_IMPLODE_DICT_SIZE3;

    // Do the compression
    if(implode(&readInputData, &writeOutputData, work_buf.ptr, &Info, &ctype, &dict_size) == CMP_NO_ERROR)
        return cast(size_t)(Info.pbOutBuff - outBuffer.ptr);
    return 0;
}

bool decompress_PKLIB(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
{
    TDataInfo Info;                             // Data information
    auto work_buf = new ubyte[EXP_BUFFER_SIZE]; // Pklib's work buffer

    // Handle no-memory condition
    if(work_buf is null)
        return 0;

    // Fill data information structure
    Info.pbInBuff     = cast(ubyte*)inBuffer.ptr;
    Info.pbInBuffEnd  = cast(ubyte*)&inBuffer[$];
    Info.pbOutBuff    = cast(ubyte*)outBuffer.ptr;
    Info.pbOutBuffEnd = cast(ubyte*)&outBuffer[$];

    // Do the decompression
    explode(&readInputData, &writeOutputData, work_buf.ptr, &Info);
    
    // If PKLIB is unable to decompress the data, return 0;
    if(Info.pbOutBuff == outBuffer.ptr)
        return false;

    // Give away the number of decompressed bytes
    outLength = Info.pbOutBuff - outBuffer.ptr;
    return true;
}

/******************************************************************************/
/*                                                                            */
/*  Support for Bzip2 compression (0x10)                                      */
/*                                                                            */
/******************************************************************************/

import bzlib;

size_t compress_BZIP2(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
{
    bz_stream strm;
    int blockSize100k = 9;
    int workFactor = 30;
    int bzError;

    // Initialize the BZIP2 compression
    strm.bzalloc = null;
    strm.bzfree  = null;

    // Blizzard uses 9 as blockSize100k, (0x30 as workFactor)
    // Last checked on Starcraft II
    if(BZ2_bzCompressInit(&strm, blockSize100k, 0, workFactor) == BZ_OK)
    {
        strm.next_in   = inBuffer.ptr;
        strm.avail_in  = cast(uint)inBuffer.length;
        strm.next_out  = outBuffer.ptr;
        strm.avail_out = cast(uint)outBuffer.length;

        // Perform the compression
        while(true)
        {
            bzError = BZ2_bzCompress(&strm, (strm.avail_in != 0) ? BZ_RUN : BZ_FINISH);
            if(bzError == BZ_STREAM_END || bzError < 0)
                break;
        }

        // Put the stream into idle state
        BZ2_bzCompressEnd(&strm);

        if(bzError > 0)
            return strm.total_out_lo32;
    }
    return 0;
}

bool decompress_BZIP2(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
{
    bz_stream strm;
    int nResult = BZ_OK;

    // Initialize the BZIP2 decompression
    strm.bzalloc = null;
    strm.bzfree  = null;
    if(BZ2_bzDecompressInit(&strm, 0, 0) == BZ_OK)
    {
        strm.next_in   = inBuffer.ptr;
        strm.avail_in  = cast(uint)inBuffer.length;
        strm.next_out  = outBuffer.ptr;
        strm.avail_out = cast(uint)outBuffer.length;

        // Perform the decompression
        while(nResult != BZ_STREAM_END)
        {
            nResult = BZ2_bzDecompress(&strm);
            
            // If any error there, break the loop 
            if(nResult < BZ_OK)
                break;
        }

        // Put the stream into idle state
        BZ2_bzDecompressEnd(&strm);

        // If all succeeded, set the number of output bytes
        if(nResult >= BZ_OK)
        {
            outLength = strm.total_out_lo32;
            return true;
        }
    }

    // Something failed, so set number of output bytes to zero
    outLength = 0;
    return false;
}

/******************************************************************************/
/*                                                                            */
/*  Support functions for LZMA compression (0x12)                             */
/*                                                                            */
/******************************************************************************/

import deimos.lzma;

//extern(C) nothrow
//{
//    import core.memory;
//    
//    SRes LZMA_Callback_Progress(void* p, ulong inSize, ulong outSize)
//    {
//        return SZ_OK;
//    }
//    
//    void* LZMA_Callback_Alloc(void* p, size_t size)
//    {
//        auto mem = GC.malloc(size);
//        GC.addRoot(mem); // gc can delete buffer while processing in C side
//        
//        return mem;
//    }
//    
//    /* address can be 0 */
//    void LZMA_Callback_Free(void* p, void* address)
//    {
//        GC.free(address); // null == no action
//    }
//}

//
// Note: So far, I haven't seen any files compressed by LZMA.
// This code haven't been verified against code ripped from Starcraft II Beta,
// but we know that Starcraft LZMA decompression code is able to decompress
// the data compressed by StormLib.
//

//size_t compress_LZMA(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
//{
//    ICompressProgress Progress;
//    CLzmaEncProps props;
//    ISzAlloc SzAlloc;
//
//    ubyte[LZMA_PROPS_SIZE] encodedProps;
//    size_t encodedPropsSize = LZMA_PROPS_SIZE;
//    SRes nResult;
//
//    // Fill the callbacks in structures
//    Progress.Progress = &LZMA_Callback_Progress;
//    SzAlloc.Alloc = &LZMA_Callback_Alloc;
//    SzAlloc.Free = &LZMA_Callback_Free;
//
//    // Initialize properties
//    LzmaEncProps_Init(&props);
//
//    // Perform compression
//    ubyte[] destBuffer = outBuffer[LZMA_HEADER_SIZE .. $];
//    size_t  destLen = destBuffer.length;
//    
//    nResult = LzmaEncode(destBuffer.ptr,
//                        &destLen,
//                         inBuffer.ptr,
//                         inBuffer.length,
//                        &props,
//                         encodedProps.ptr,
//                        &encodedPropsSize,
//                         0,
//                        &Progress,
//                        &SzAlloc,
//                        &SzAlloc);
//    if(nResult != SZ_OK)
//        return 0;
//
//    // If we failed to compress the data
//    if(destLen >= outBuffer.length)
//        return 0;
//
//    // Write "useFilter" variable. Blizzard MPQ must not use filter.
//    outBuffer[0] = 0;
//    outBuffer = outBuffer[1 .. $];
//    
//    // Copy the encoded properties to the output buffer
//    outBuffer[0 .. encodedPropsSize] = encodedProps[];
//    pbOutBuffer += encodedPropsSize;
//
//    // Copy the size of the data
//    outBuffer[0] = cast(ubyte)(inBuffer.length >> 0x00);
//    outBuffer[1] = cast(ubyte)(inBuffer.length >> 0x08);
//    outBuffer[2] = cast(ubyte)(inBuffer.length >> 0x10);
//    outBuffer[3] = cast(ubyte)(inBuffer.length >> 0x18);
//    outBuffer[4] = 0;
//    outBuffer[5] = 0;
//    outBuffer[6] = 0;
//    outBuffer[7] = 0;
//
//    // Give the size of the data to the caller
//    return destLen + LZMA_HEADER_SIZE;
//}

enum INTEGRITY_CHECK = lzma_check.LZMA_CHECK_CRC64;

size_t compress_LZMA(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
{
    lzma_check check = INTEGRITY_CHECK;
    lzma_stream strm = lzma_stream.init;
    lzma_ret ret;
    size_t outLength;
    
    ret = lzma_easy_encoder(&strm, nCmpLevel, check);
    if(ret != lzma_ret.LZMA_OK)
    {
        return 0;
    }
    
    strm.next_in = inBuffer.ptr;
    strm.avail_in = inBuffer.length;
    
    // loop until there's no pending compressed output
    do
    {
        strm.next_out = outBuffer.ptr;
        strm.avail_out = outBuffer.length;
        
        ret = lzma_code(&strm, lzma_action.LZMA_FINISH);
        
        if ((ret != lzma_ret.LZMA_OK) && (ret != lzma_ret.LZMA_STREAM_END))
        {
            lzma_end(&strm);
            return 0;
        }
        else
        {
            outLength += outBuffer.length - strm.avail_out;
            outBuffer = outBuffer[outBuffer.length - strm.avail_out .. $];
        }
    }
    while(strm.avail_out == 0);
    
    lzma_end(&strm);
    return outLength;
}

//bool decompress_LZMA(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
//{
//    ELzmaStatus LzmaStatus;
//    ISzAlloc SzAlloc;
//    SRes nResult;
//
//    // There must be at least 0x0E bytes in the buffer
//    if(inBuffer.length <= LZMA_HEADER_SIZE) 
//        return false;
//
//    // We only accept blocks that have no filter used
//    if(outBuffer[0] != 0)
//        return false;
//
//    // Fill the callbacks in structures
//    SzAlloc.Alloc = &LZMA_Callback_Alloc;
//    SzAlloc.Free = &LZMA_Callback_Free;
//
//    // Perform compression
//    outLength = outBuffer.length;
//    srcLen = cbInBuffer - LZMA_HEADER_SIZE;
//    nResult = LzmaDecode(outBuffer.ptr,
//                        &outLength,
//                         inBuffer[LZMA_HEADER_SIZE ..  $].ptr,
//                        &srcLen,
//                         inBuffer[1 .. $].ptr, 
//                         LZMA_PROPS_SIZE,
//                         LZMA_FINISH_END,
//                        &LzmaStatus,
//                        &SzAlloc);
//    if(nResult != SZ_OK)
//        return false;
//
//    return true;
//}
//
//bool decompress_LZMA_MPK(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
//{
//    ELzmaStatus LzmaStatus;
//    ISzAlloc SzAlloc;
//
//    SRes nResult;
//    immutable ubyte[] LZMA_Props = [0x5D, 0x00, 0x00, 0x00, 0x01];
//
//    // There must be at least 0x0E bytes in the buffer
//    if(srcLen <= LZMA_Props.length)
//        return false;
//
//    // Verify the props header
//    if(inBuffer[0 .. LZMA_Props.length] != LZMA_Props[])
//        return false;
//
//    // Fill the callbacks in structures
//    SzAlloc.Alloc = &LZMA_Callback_Alloc;
//    SzAlloc.Free = &LZMA_Callback_Free;
//
//    // Perform compression
//    size_t srcLen = inBuffer.length - LZMA_Props.length;
//    outLength = outBuffer.length;
//    nResult = LzmaDecode(outBuffer.ptr,
//                        &outLength,
//                         srcBuffer[LZMA_Props.length .. $],
//                        &srcLen,
//                         srcBuffer.ptr, 
//                         LZMA_Props.length,
//                         LZMA_FINISH_END,
//                        &LzmaStatus,
//                        &SzAlloc);
//    if(nResult != SZ_OK)
//        return 0;
//
//    return true;
//}

bool decompress_LZMA(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
{
    lzma_stream strm = lzma_stream.init; /* alloc and init lzma_stream struct */
    uint flags = LZMA_TELL_UNSUPPORTED_CHECK;
    ulong memory_limit = ulong.max; /* no memory limit */

    bool out_finished = false;
    lzma_ret ret;
    
    /* initialize xz decoder */
    ret = lzma_stream_decoder (&strm, memory_limit, flags);
    if (ret != lzma_ret.LZMA_OK)
    {
        return false;
    }

    strm.next_in = inBuffer.ptr;
    strm.avail_in = inBuffer.length;

    /* loop until there's no pending decompressed output */
    do
    {
        /* out_buf is clean at this point */
        strm.next_out = outBuffer.ptr;
        strm.avail_out = outBuffer.length;

        /* decompress data */
        ret = lzma_code (&strm, lzma_action.LZMA_FINISH);

        if ((ret != lzma_ret.LZMA_OK) && (ret != lzma_ret.LZMA_STREAM_END))
        {
            return false;
        }
        else
        {
            outLength += outBuffer.length - strm.avail_out;
            outBuffer = outBuffer[outBuffer.length - strm.avail_out .. $];
        }
    }
    while (strm.avail_out == 0);

    lzma_end(&strm);
    return true;
}

/******************************************************************************/
/*                                                                            */
/*  Support functions for SPARSE compression (0x20)                           */
/*                                                                            */
/******************************************************************************/

import storm.sparse;

size_t Compress_SPARSE(ubyte[] outBuffer, ubyte[] inBuffer, ref int pCmpType, int nCmpLevel)
{
    size_t length;
    compressSparse(outBuffer, length, inBuffer);
    return length;
}

bool Decompress_SPARSE(ubyte[] outBuffer, out size_t outLength, ubyte[] inBuffer)
{
    return decompressSparse(outBuffer, outLength, inBuffer);
}