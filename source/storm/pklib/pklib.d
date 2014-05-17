/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
// Original header
/*****************************************************************************/
/* pklib.h                                Copyright (c) Ladislav Zezula 2003 */
/*---------------------------------------------------------------------------*/
/* Header file for PKWARE Data Compression Library                           */
/*---------------------------------------------------------------------------*/
/*   Date    Ver   Who  Comment                                              */
/* --------  ----  ---  -------                                              */
/* 31.03.03  1.00  Lad  The first version of pkware.h                        */
/*****************************************************************************/
module storm.pklib.pklib;

//-----------------------------------------------------------------------------
// Defines

enum CMP_BINARY             = 0;            // Binary compression
enum CMP_ASCII              = 1;            // Ascii compression

enum CMP_NO_ERROR           = 0;
enum CMP_INVALID_DICTSIZE   = 1;
enum CMP_INVALID_MODE       = 2;
enum CMP_BAD_DATA           = 3;
enum CMP_ABORT              = 4;

enum CMP_IMPLODE_DICT_SIZE1   = 1024;       // Dictionary size of 1024
enum CMP_IMPLODE_DICT_SIZE2   = 2048;       // Dictionary size of 2048
enum CMP_IMPLODE_DICT_SIZE3   = 4096;       // Dictionary size of 4096


//-----------------------------------------------------------------------------
// Internal structures

// Compression structure
struct TCmpStruct
{
    uint   distance;                // 0000: Backward distance of the currently found repetition, decreased by 1
    uint   out_bytes;               // 0004: # bytes available in out_buff            
    uint   out_bits;                // 0008: # of bits available in the last out byte
    uint   dsize_bits;              // 000C: Number of bits needed for dictionary size. 4 = 0x400, 5 = 0x800, 6 = 0x1000
    uint   dsize_mask;              // 0010: Bit mask for dictionary. 0x0F = 0x400, 0x1F = 0x800, 0x3F = 0x1000
    uint   ctype;                   // 0014: Compression type (CMP_ASCII or CMP_BINARY)
    uint   dsize_bytes;             // 0018: Dictionary size in bytes
    ubyte  dist_bits[0x40];         // 001C: Distance bits
    ubyte  dist_codes[0x40];        // 005C: Distance codes
    ubyte  nChBits[0x306];          // 009C: Table of literal bit lengths to be put to the output stream
    ushort nChCodes[0x306];         // 03A2: Table of literal codes to be put to the output stream
    ushort offs09AE;                // 09AE: 

    void*  param;                   // 09B0: User parameter
    uint function(ubyte *buf, uint *size, void *param) read_buf;  // 9B4
    void function(ubyte *buf, uint *size, void *param) write_buf; // 9B8

    ushort offs09BC[0x204];         // 09BC:
    uint   offs0DC4;                // 0DC4: 
    ushort phash_to_index[0x900];   // 0DC8: Array of indexes (one for each PAIR_HASH) to the "pair_hash_offsets" table
    ushort phash_to_index_end;      // 1FC8: End marker for "phash_to_index" table
    ubyte  out_buff[0x802];         // 1FCA: Compressed data
    ubyte  work_buff[0x2204];       // 27CC: Work buffer
                                    //  + DICT_OFFSET  => Dictionary
                                    //  + UNCMP_OFFSET => Uncompressed data
    ushort phash_offs[0x2204];      // 49D0: Table of offsets for each PAIR_HASH
}

enum CMP_BUFFER_SIZE = TCmpStruct.sizeof; // Size of compression structure.
                                          // Defined as 36312 in pkware header file


// Decompression structure
struct TDcmpStruct
{
    uint offs0000;                 // 0000
    uint ctype;                    // 0004: Compression type (CMP_BINARY or CMP_ASCII)
    uint outputPos;                // 0008: Position in output buffer
    uint dsize_bits;               // 000C: Dict size (4, 5, 6 for 0x400, 0x800, 0x1000)
    uint dsize_mask;               // 0010: Dict size bitmask (0x0F, 0x1F, 0x3F for 0x400, 0x800, 0x1000)
    uint bit_buff;                 // 0014: 16-bit buffer for processing input data
    uint extra_bits;               // 0018: Number of extra (above 8) bits in bit buffer
    uint in_pos;                   // 001C: Position in in_buff
    uint in_bytes;                 // 0020: Number of bytes in input buffer
    void        * param;           // 0024: Custom parameter
    uint function(ubyte *buf, uint *size, void *param) read_buf; // Pointer to function that reads data from the input stream
    void function(ubyte *buf, uint *size, void *param) write_buf;// Pointer to function that writes data to the output stream

    ubyte out_buff[0x2204];         // 0030: Output circle buffer.
                                    //       0x0000 - 0x0FFF: Previous uncompressed data, kept for repetitions
                                    //       0x1000 - 0x1FFF: Currently decompressed data
                                    //       0x2000 - 0x2203: Reserve space for the longest possible repetition
    ubyte in_buff[0x800];           // 2234: Buffer for data to be decompressed
    ubyte DistPosCodes[0x100];      // 2A34: Table of distance position codes
    ubyte LengthCodes[0x100];       // 2B34: Table of length codes
    ubyte offs2C34[0x100];          // 2C34: Buffer for 
    ubyte offs2D34[0x100];          // 2D34: Buffer for 
    ubyte offs2E34[0x80];           // 2EB4: Buffer for 
    ubyte offs2EB4[0x100];          // 2EB4: Buffer for 
    ubyte ChBitsAsc[0x100];         // 2FB4: Buffer for 
    ubyte DistBits[0x40];           // 30B4: Numbers of bytes to skip copied block length
    ubyte LenBits[0x10];            // 30F4: Numbers of bits for skip copied block length
    ubyte ExLenBits[0x10];          // 3104: Number of valid bits for copied block
    ushort LenBase[0x10];           // 3114: Buffer for 
}

enum EXP_BUFFER_SIZE = TDcmpStruct.sizeof;  // Size of decompression structure
                                            // Defined as 12596 in pkware headers

//-----------------------------------------------------------------------------
// Public functions

public import storm.pklib.implode;
public import storm.pklib.explode;

// The original name "crc32" was changed to "crc32pk" due
// to compatibility with zlib
public import storm.pklib.crc32;
