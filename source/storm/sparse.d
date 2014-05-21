/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, ShadowFlare <BlakFlare@hotmail.com>, NCrashed <ncrashed@gmail.com>
*/
/*****************************************************************************/
/* sparse.h                               Copyright (c) Ladislav Zezula 2010 */
/*---------------------------------------------------------------------------*/
/* implementation of Sparse compression, used in Starcraft II                */
/*---------------------------------------------------------------------------*/
/*   Date    Ver   Who  Comment                                              */
/* --------  ----  ---  -------                                              */
/* 05.03.10  1.00  Lad  The first version of sparse.h                        */
/*****************************************************************************/
/*****************************************************************************/
/* huffman.cpp                       Copyright (c) Ladislav Zezula 1998-2003 */
/*---------------------------------------------------------------------------*/
/* This module contains Huffmann (de)compression methods                     */
/*                                                                           */
/* Authors : Ladislav Zezula (ladik.zezula.net)                              */
/*           ShadowFlare     (BlakFlare@hotmail.com)                         */
/*                                                                           */
/*---------------------------------------------------------------------------*/
/*   Date    Ver   Who  Comment                                              */
/* --------  ----  ---  -------                                              */
/* xx.xx.xx  1.00  Lad  The first version of dcmp.cpp                        */
/* 03.05.03  1.00  Lad  Added compression methods                            */
/* 19.11.03  1.01  Dan  Big endian handling                                  */
/* 08.12.03  2.01  Dan  High-memory handling (> 0x80000000)                  */
/*****************************************************************************/
module storm.sparse;

void compressSparse(ubyte[] outBuffer, out size_t outSize, ubyte[] inBuffer)
{
    ubyte * pbOutBufferEnd = outBuffer.ptr + outBuffer.length;
    ubyte * pbInBufferEnd = inBuffer.ptr + inBuffer.length;
    ubyte * pbLastNonZero = inBuffer.ptr;
    ubyte * pbOutBuffer0 = outBuffer.ptr;
    ubyte * pbInBuffPtr = inBuffer.ptr;
    ubyte * pbOutBuffer = outBuffer.ptr;
    ubyte * pbInBuffer = inBuffer.ptr;
    size_t NumberOfNonZeros;
    size_t NumberOfZeros;

    // There must be at least 4 bytes of free space in the output buffer now
    if((pbInBuffer + 4) >= pbInBufferEnd)
        return;

    // Put the original data length (in little endian)
    *pbOutBuffer++ = cast(ubyte)(inBuffer.length >> 0x18);
    *pbOutBuffer++ = cast(ubyte)(inBuffer.length >> 0x10);
    *pbOutBuffer++ = cast(ubyte)(inBuffer.length >> 0x08);
    *pbOutBuffer++ = cast(ubyte)(inBuffer.length >> 0x00);

    // If there is at least 3 bytes in the input buffer, do this loop
    while(pbInBuffer < (pbInBufferEnd - 3))
    {
        // Reset the zero count and frontal pointer
        pbLastNonZero = pbInBuffer;
        pbInBuffPtr   = pbInBuffer;
        NumberOfZeros = 0;

        if(pbInBuffPtr < pbInBufferEnd)
        {
            do
            {
                // Count number of zeros
                if(*pbInBuffPtr == 0)
                {
                    NumberOfZeros++;
                }
                else
                {
                    // Were there at least 3 zeros before? If yes, we need to flush the data
                    if(NumberOfZeros >= 3)
                        break;
                    pbLastNonZero = pbInBuffPtr + 1;
                    NumberOfZeros = 0;
                }
            }
            while(++pbInBuffPtr < pbInBufferEnd);
        }

        // Get number of nonzeros that we found so far and flush them
        NumberOfNonZeros = pbLastNonZero - pbInBuffer;
        if(NumberOfNonZeros != 0)
        {
            // Process blocks that are longer than 0x81 nonzero bytes
            while(NumberOfNonZeros > 0x81)
            {
                // Verify if we still have enough space in output buffer
                if((pbOutBuffer + 0x81) >= pbOutBufferEnd)
                    return;

                // Put marker that means "0x80 of nonzeros"
                *pbOutBuffer++ = 0xFF;
                pbOutBuffer[0 .. 0x80] = pbInBuffer[0 .. 0x80];
                
                // Adjust counter of nonzeros and both pointers
                NumberOfNonZeros -= 0x80;
                pbOutBuffer += 0x80;
                pbInBuffer += 0x80;
            }

            // BUGBUG: The following code will be triggered if the NumberOfNonZeros
            // was 0x81 before. It will copy just one byte. This seems like a bug to me,
            // but since I want StormLib to be exact like Blizzard code is, I will keep
            // it that way here
            if(NumberOfNonZeros > 0x80)
            {
                // Verify if we still have enough space in output buffer
                if((pbOutBuffer + 2) >= pbOutBufferEnd)
                    return;

                // Put marker that means "1 nonzero byte"
                *pbOutBuffer++ = 0x80;
                *pbOutBuffer = *pbInBuffer;
                
                // Adjust counter of nonzeros and both pointers
                NumberOfNonZeros--;
                pbOutBuffer++;
                pbInBuffer++;
            }

            // If there is 1 nonzero or more, put the block
            if(NumberOfNonZeros >= 0x01)
            {
                // Verify if we still have enough space in output buffer
                if((pbOutBuffer + NumberOfNonZeros + 1) >= pbOutBufferEnd)
                    return;

                // Put marker that means "Several nonzero bytes"
                *pbOutBuffer++ = cast(ubyte)(0x80 | (NumberOfNonZeros - 1));
                pbOutBuffer[0 .. NumberOfNonZeros] = pbInBuffer[0 .. NumberOfNonZeros];

                // Adjust pointers
                pbOutBuffer += NumberOfNonZeros;
                pbInBuffer += NumberOfNonZeros;
            }
            else
            {
                // Verify if we still have enough space in output buffer
                if((pbOutBuffer + 2) >= pbOutBufferEnd)
                    return;

                // Put marker that means "1 nonzero byte"
                *pbOutBuffer++ = 0x80;
                *pbOutBuffer = *pbInBuffer;

                // Adjust pointers
                pbOutBuffer++;
                pbInBuffer++;
            }
        }

        // Now flush all zero bytes
        while(NumberOfZeros > 0x85)
        {
            // Do we have at least 2 bytes in the output buffer ?
            if((pbOutBuffer + 1) >= pbOutBufferEnd)
                return;

            // Put marker that means "0x82 zeros"
            *pbOutBuffer++ = 0x7F;

            // Adjust zero counter and input pointer
            NumberOfZeros -= 0x82;
            pbInBuffer += 0x82;
        }

        // If we got more than 0x82 zeros, flush 3 of them now
        if(NumberOfZeros > 0x82)
        {
            // Do we have at least 2 bytes in the output buffer ?
            if((pbOutBuffer + 1) >= pbOutBufferEnd)
                return;

            // Put marker that means "0x03 zeros"
            *pbOutBuffer++ = 0;

            // Adjust zero counter and input pointer
            NumberOfZeros -= 0x03;
            pbInBuffer += 0x03;
        }

        // Is there at least three zeros ?
        if(NumberOfZeros >= 3)
        {
            // Do we have at least 2 bytes in the output buffer ?
            if((pbOutBuffer + 1) >= pbOutBufferEnd)
                return;

            // Put marker that means "Several zeros"
            *pbOutBuffer++ = cast(ubyte)(NumberOfZeros - 3);
    
            // Adjust pointer
            pbInBuffer += NumberOfZeros;
        }
    }

    // Flush last three bytes
    if(pbInBuffer < pbInBufferEnd)
    {
        pbInBuffPtr = pbInBuffer;

        for(;;)
        {
            if(*pbInBuffPtr++ != 0)
            {
                // Get number of bytes remaining
                NumberOfNonZeros = (pbInBufferEnd - pbInBuffer);

                // Not enough space in the output buffer ==> exit
                if((pbOutBuffer + NumberOfNonZeros + 1) >= pbOutBufferEnd)
                    return;

                // Terminate with a marker that means "0x80 of nonzeros"
                *pbOutBuffer++ = 0xFF;
                pbOutBuffer[0 .. NumberOfNonZeros] = pbInBuffer[0 .. NumberOfNonZeros]; 
                
                // Adjust pointer
                pbOutBuffer += NumberOfNonZeros;
                break;
            }
            else
            {
                // Is there are more chars in the input buffer
                if(pbInBuffPtr < pbInBufferEnd)
                    continue;

                // If the compression will not compress it by even 1 byte, do nothing
                if((pbOutBuffer + 1) >= pbOutBufferEnd)
                    return;

                // Terminate with a chunk that means "0x82 of zeros"
                *pbOutBuffer++ = 0x7F;
                break;
            }
        }
    }

    // Out the length of the output buffer
    outSize = cast(size_t)(pbOutBuffer - pbOutBuffer0);
}

bool decompressSparse(ubyte[] outBuffer, out size_t outSize, ubyte[] inBuffer)
{
    ubyte * pbInBufferEnd = inBuffer.ptr + inBuffer.length;
    ubyte * pbOutBuffer = outBuffer.ptr;
    ubyte * pbInBuffer = inBuffer.ptr;
    uint cbChunkSize;
    uint cbOutBuffer = 0;
    uint OneByte;

    // Don't decompress anything that is shorter than 5 bytes
    if(inBuffer.length < 5)
        return false;

    // Get the 32-bits from the input stream
    OneByte = *pbInBuffer++;
    cbOutBuffer |= (OneByte << 0x18);
    OneByte = *pbInBuffer++;
    cbOutBuffer |= (OneByte << 0x10);
    OneByte = *pbInBuffer++;
    cbOutBuffer |= (OneByte << 0x08);
    OneByte = *pbInBuffer++;
    cbOutBuffer |= (OneByte << 0x00);

    // Verify the size of the stream against the output buffer size
    if(cbOutBuffer > outBuffer.length)
        return 0;

    // Put the output size to the buffer
    outSize = cast(size_t)cbOutBuffer;

    // Process the input buffer
    while(pbInBuffer < pbInBufferEnd)
    {
        // Get (next) byte from the stream
        OneByte = *pbInBuffer++;

        // If highest bit, it means that that normal data follow
        if(OneByte & 0x80)
        {
            cbChunkSize = (OneByte & 0x7F) + 1;
            cbChunkSize = (cbChunkSize < cbOutBuffer) ? cbChunkSize : cbOutBuffer;
            pbOutBuffer[0 .. cbChunkSize] = pbInBuffer[0 .. cbChunkSize];
            pbInBuffer += cbChunkSize;
        }
        else
        {
            cbChunkSize = (OneByte & 0x7F) + 3;
            cbChunkSize = (cbChunkSize < cbOutBuffer) ? cbChunkSize : cbOutBuffer;
            pbOutBuffer[0 .. cbChunkSize] = 0;
        }

        // Increment output buffer pointer
        pbOutBuffer += cbChunkSize;
        cbOutBuffer -= cbChunkSize;
    }

    return true;
}
