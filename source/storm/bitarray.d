/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.bitarray;

struct BitArray
{
    /// Total number of bits that are available
    size_t numberOfBits;
    /// Array of elements (variable length)
    ubyte[] elements;
    
    this(size_t numberOfBits, ubyte fillValue)
    {
        this.numberOfBits = numberOfBits;
        size_t nSize = (numberOfBits + 7) / 8;
        
        // Allocate the bit array
        elements = new ubyte[nSize];
        elements[] = fillValue;
    }
    // Testing filling with ranges
    unittest
    {
        auto arr = new ubyte[4];
        arr[] = 42u;
        
        assert(arr == [42u,42u,42u,42u]);
    }
}

void GetBits(const ref BitArray array, size_t nBitPosition, size_t nBitLength, ubyte[] buffer)
{
    size_t nBytePosition0 = nBitPosition / 8;
    size_t nBytePosition1 = nBytePosition0 + 1;
    size_t nByteLength = nBitLength / 8;
    size_t nBitOffset = nBitPosition & 0x07;
    ubyte bitBuffer;
    
    debug
    {
        // Check if the target is properly zeroed
        foreach(ref b; buffer)
            assert(b == 0);
    }
    
    // Copy whole bytes, if any
    foreach(i; 0..nByteLength)
    {
        // Is the current position in the Elements byte-aligned?
        if(nBitOffset != 0)
        {
            buffer[i] = cast(ubyte)((array.elements[nBytePosition0] >> nBitOffset) | (array.elements[nBytePosition1] << (0x08 - nBitOffset)));
        }
        else
        {
            buffer[i] = array.elements[nBytePosition0];
        }

        // Move byte positions and lengths
        nBytePosition1++;
        nBytePosition0++;
    }
    
    // Get the rest of the bits
    nBitLength = nBitLength & 0x07;
    if(nBitLength != 0)
    {
        buffer[nByteLength] = cast(ubyte)(array.elements[nBytePosition0] >> nBitOffset);

        if(nBitLength > (8 - nBitOffset))
            buffer[nByteLength] = cast(ubyte)((array.elements[nBytePosition1] << (8 - nBitOffset)) | (array.elements[nBytePosition0] >> nBitOffset));

        buffer[nByteLength] &= (0x01 << nBitLength) - 1;
    }
}

private immutable ushort[] SetBitsMask = [0x00, 0x01, 0x03, 0x07, 0x0F, 0x1F, 0x3F, 0x7F, 0xFF];

void SetBits(ref BitArray array, size_t nBitPosition, size_t nBitLength, ubyte[] buffer)
{
    size_t nBytePosition = nBitPosition / 8;
    size_t nBitOffset = nBitPosition & 0x07;
    ushort BitBuffer = 0;
    ushort AndMask = 0;
    ushort OneByte = 0;

    ubyte* pbBuffer = buffer.ptr;
    
    // Copy whole bytes, if any
    while(nBitLength > 8)
    {
        // Reload the bit buffer
        OneByte = *pbBuffer++;

        // Update the BitBuffer and AndMask for the bit array
        BitBuffer = cast(ushort)((BitBuffer >> 0x08) | (OneByte << nBitOffset));
        AndMask = cast(ushort)((AndMask >> 0x08) | (0x00FF << nBitOffset));

        // Update the byte in the array
        array.elements[nBytePosition] = cast(ubyte)((array.elements[nBytePosition] & ~AndMask) | BitBuffer);

        // Move byte positions and lengths
        nBytePosition++;
        nBitLength -= 0x08;
    }

    if(nBitLength != 0)
    {
        // Reload the bit buffer
        OneByte = *pbBuffer;

        // Update the AND mask for the last bit
        BitBuffer = cast(ushort)((BitBuffer >> 0x08) | (OneByte << nBitOffset));
        AndMask = cast(ushort)((AndMask >> 0x08) | (SetBitsMask[nBitLength] << nBitOffset));

        // Update the byte in the array
        array.elements[nBytePosition] = cast(ubyte)((array.elements[nBytePosition] & ~AndMask) | BitBuffer);

        // Update the next byte, if needed
        if(AndMask & 0xFF00)
        {
            nBytePosition++;
            BitBuffer >>= 0x08;
            AndMask >>= 0x08;

            array.elements[nBytePosition] = cast(ubyte)((array.elements[nBytePosition] & ~AndMask) | BitBuffer);
        }
    }
}

