/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Swapping functions
*/
module storm.swapping;

version(LittleEndian)
{
    void nothing(T...)(T args) {}
    T id(T)(T a) {return a;}
    
    alias    BSWAP_INT16_UNSIGNED          = id;
    alias    BSWAP_INT16_SIGNED            = id;
    alias    BSWAP_INT32_UNSIGNED          = id;
    alias    BSWAP_INT32_SIGNED            = id;
    alias    BSWAP_INT64_SIGNED            = id;
    alias    BSWAP_INT64_UNSIGNED          = id;
    alias    BSWAP_ARRAY16_UNSIGNED        = nothing;
    alias    BSWAP_ARRAY32_UNSIGNED        = nothing;
    alias    BSWAP_ARRAY64_UNSIGNED        = nothing;
    alias    BSWAP_PART_HEADER             = nothing;
    alias    BSWAP_TMPQHEADER              = nothing;
    alias    BSWAP_TMPKHEADER              = nothing;
}
else
{
    alias    BSWAP_INT16_SIGNED            = SwapInt16;
    alias    BSWAP_INT16_UNSIGNED          = SwapUInt16;
    alias    BSWAP_INT32_SIGNED            = SwapInt32;
    alias    BSWAP_INT32_UNSIGNED          = SwapUInt32;
    alias    BSWAP_INT64_SIGNED            = SwapInt64;
    alias    BSWAP_INT64_UNSIGNED          = SwapUInt64;
    alias    BSWAP_ARRAY16_UNSIGNED        = ConvertUInt16Buffer;
    alias    BSWAP_ARRAY32_UNSIGNED        = ConvertUInt32Buffer;
    alias    BSWAP_ARRAY64_UNSIGNED        = ConvertUInt64Buffer;
    alias    BSWAP_TMPQHEADER              = ConvertTMPQHeader;
    alias    BSWAP_TMPKHEADER              = ConvertTMPKHeader;
}


version(BigEndian)
{
    import storm.mpq;
    
    //
    // Note that those functions are implemented for Mac operating system,
    // as this is the only supported platform that uses big endian.
    //
    
    // Swaps a signed 16-bit integer
    short SwapInt16(ushort data)
    {
        return cast(short)CFSwapInt16(data);
    }
    
    // Swaps an unsigned 16-bit integer
    ushort SwapUInt16(ushort data)
    {
        return CFSwapInt16(data);
    }
    
    // Swaps signed 32-bit integer
    int SwapInt32(uint data)
    {
        return cast(int)CFSwapInt32(data);
    }
    
    // Swaps an unsigned 32-bit integer
    uint SwapUInt32(uint data)
    {
        return CFSwapInt32(data);
    }
    
    // Swaps signed 64-bit integer
    long SwapInt64(long data)
    {
           return cast(long)CFSwapInt64(data);
    }
    
    // Swaps an unsigned 64-bit integer
    ulong SwapUInt64(ulong data)
    {
           return CFSwapInt64(data);
    }
    
    // Swaps array of unsigned 16-bit integers
    void ConvertUInt16Buffer(ubyte[] ptr)
    {
        ushort* buffer = (cast(ushort[])ptr).ptr;
        size_t nElements = ptr.length / ushort.sizeof;
    
        while(nElements-- > 0)
        {
            *buffer = SwapUInt16(*buffer);
            buffer++;
        }
    }
    
    // Swaps array of unsigned 32-bit integers
    void ConvertUInt32Buffer(ubyte[] ptr)
    {
        uint* buffer = (cast(uint[])ptr).ptr;
        size_t nElements = ptr.length / uint.sizeof;
    
        while(nElements-- > 0)
        {
            *buffer = SwapUInt32(*buffer);
            buffer++;
        }
    }
    
    // Swaps array of unsigned 64-bit integers
    void ConvertUInt64Buffer(ubyte[] ptr)
    {
        ulong * buffer = (cast(ulong[])ptr).ptr;
        size_t nElements = ptr.length / ulong.sizeof;
    
        while(nElements-- > 0)
        {
            *buffer = SwapUInt64(*buffer);
            buffer++;
        }
    }
    
    // Swaps the TMPQHeader structure
    void ConvertTMPQHeader(void* header, ushort _version)
    {
        TMPQHeader * theHeader = cast(TMPQHeader *)header;
    
        // Swap header part version 1
        if(_version == MPQ_FORMAT_VERSION_1)
        {
            theHeader.dwID = SwapUInt32(theHeader.dwID);
            theHeader.dwHeaderSize = SwapUInt32(theHeader.dwHeaderSize);
            theHeader.dwArchiveSize = SwapUInt32(theHeader.dwArchiveSize);
            theHeader.wFormatVersion = SwapUInt16(theHeader.wFormatVersion);
            theHeader.wSectorSize = SwapUInt16(theHeader.wSectorSize);
            theHeader.dwHashTablePos = SwapUInt32(theHeader.dwHashTablePos);
            theHeader.dwBlockTablePos = SwapUInt32(theHeader.dwBlockTablePos);
            theHeader.dwHashTableSize = SwapUInt32(theHeader.dwHashTableSize);
            theHeader.dwBlockTableSize = SwapUInt32(theHeader.dwBlockTableSize);
        }
    
        if(_version == MPQ_FORMAT_VERSION_2)
        {
            theHeader.HiBlockTablePos64 = SwapUInt64(theHeader.HiBlockTablePos64);
            theHeader.wHashTablePosHi = SwapUInt16(theHeader.wHashTablePosHi);
            theHeader.wBlockTablePosHi = SwapUInt16(theHeader.wBlockTablePosHi);
        }
    
        if(_version == MPQ_FORMAT_VERSION_3)
        {
            theHeader.ArchiveSize64 = SwapUInt64(theHeader.ArchiveSize64);
            theHeader.BetTablePos64 = SwapUInt64(theHeader.BetTablePos64);
            theHeader.HetTablePos64 = SwapUInt64(theHeader.HetTablePos64);
        }
    
        if(_version == MPQ_FORMAT_VERSION_4)
        {
            theHeader.HashTableSize64    = SwapUInt64(theHeader.HashTableSize64);
            theHeader.BlockTableSize64   = SwapUInt64(theHeader.BlockTableSize64);
            theHeader.HiBlockTableSize64 = SwapUInt64(theHeader.HiBlockTableSize64);
            theHeader.HetTableSize64     = SwapUInt64(theHeader.HetTableSize64);
            theHeader.BetTableSize64     = SwapUInt64(theHeader.BetTableSize64);
        }
    }

}