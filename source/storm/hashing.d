/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.hashing;

import storm.common;
import tomcrypt.tomcrypt;

/// Verified: If there is 1 file, hash table size is 4
enum HASH_TABLE_SIZE_MIN       = 0x00000004;  
/// Default hash table size for empty MPQs
enum HASH_TABLE_SIZE_DEFAULT   = 0x00001000;  
/// Maximum acceptable hash table size
enum HASH_TABLE_SIZE_MAX       = 0x00080000;  

/// Hashing function
alias HASH_STRING = uint function(string fileName, uint hashType);

auto HASH_INDEX_MASK(T)(T ha) { return ha.pHeader.dwHashTableSize ? (ha.pHeader.dwHashTableSize - 1) : 0; }

enum STORM_BUFFER_SIZE       = 0x500;

/// Buffer for the decryption engine
private uint[STORM_BUFFER_SIZE] StormBuffer;    
private bool  bMpqCryptographyInitialized = false;

void InitializeMpqCryptography()
{
    uint dwSeed = 0x00100001;
    uint index1 = 0;
    uint index2 = 0;
    int   i;

    // Initialize the decryption buffer.
    // Do nothing if already done.
    if(bMpqCryptographyInitialized == false)
    {
        for(index1 = 0; index1 < 0x100; index1++)
        {
            for(index2 = index1, i = 0; i < 5; i++, index2 += 0x100)
            {
                uint temp1, temp2;

                dwSeed = (dwSeed * 125 + 3) % 0x2AAAAB;
                temp1  = (dwSeed & 0xFFFF) << 0x10;

                dwSeed = (dwSeed * 125 + 3) % 0x2AAAAB;
                temp2  = (dwSeed & 0xFFFF);

                StormBuffer[index2] = (temp1 | temp2);
            }
        }

        // Also register both MD5 and SHA1 hash algorithms
        register_hash(&md5_desc);
        register_hash(&sha1_desc);

        // Use LibTomMath as support math library for LibTomCrypt
        ltc_mp = cast()ltm_desc;

        // Don't do that again
        bMpqCryptographyInitialized = true;
    }
}

uint HashString(string szFileName, uint dwHashType)
{
    ubyte[] pbKey   = cast(ubyte[])szFileName;
    uint  dwSeed1 = 0x7FED7FED;
    uint  dwSeed2 = 0xEEEEEEEE;

    foreach(ref c; pbKey)
    {
        // Convert the input character to uppercase
        // Convert slash (0x2F) to backslash (0x5C)
        auto ch = AsciiToUpperTable[cast(size_t)c];

        dwSeed1 = StormBuffer[dwHashType + ch] ^ (dwSeed1 + dwSeed2);
        dwSeed2 = ch + dwSeed1 + dwSeed2 + (dwSeed2 << 5) + 3;
    }

    return dwSeed1;
}

uint HashStringSlash(string szFileName, uint dwHashType)
{
    ubyte[] pbKey   = cast(ubyte[])szFileName;
    uint  dwSeed1 = 0x7FED7FED;
    uint  dwSeed2 = 0xEEEEEEEE;

    foreach(ref c; pbKey)
    {
        // Convert the input character to uppercase
        // DON'T convert slash (0x2F) to backslash (0x5C)
        auto ch = AsciiToUpperTable_Slash[cast(size_t)c];

        dwSeed1 = StormBuffer[dwHashType + ch] ^ (dwSeed1 + dwSeed2);
        dwSeed2 = ch + dwSeed1 + dwSeed2 + (dwSeed2 << 5) + 3;
    }

    return dwSeed1;
}

uint HashStringLower(string szFileName, uint dwHashType)
{
    ubyte[] pbKey   = cast(ubyte[])szFileName;
    uint  dwSeed1 = 0x7FED7FED;
    uint  dwSeed2 = 0xEEEEEEEE;

    foreach(ref c; pbKey)
    {
        // Convert the input character to lower
        // DON'T convert slash (0x2F) to backslash (0x5C)
        auto ch = AsciiToLowerTable[cast(size_t)c];

        dwSeed1 = StormBuffer[dwHashType + ch] ^ (dwSeed1 + dwSeed2);
        dwSeed2 = ch + dwSeed1 + dwSeed2 + (dwSeed2 << 5) + 3;
    }

    return dwSeed1;
}

//-----------------------------------------------------------------------------
// Calculates the hash table size for a given amount of files

uint GetHashTableSizeForFileCount(uint dwFileCount)
{
    uint dwPowerOfTwo = HASH_TABLE_SIZE_MIN;

    // For zero files, there is no hash table needed
    if(dwFileCount == 0)
        return 0;

    // Round the hash table size up to the nearest power of two
    // Don't allow the hash table size go over allowed maximum
    while(dwPowerOfTwo < HASH_TABLE_SIZE_MAX && dwPowerOfTwo < dwFileCount)
        dwPowerOfTwo <<= 1;
    return dwPowerOfTwo;
}

//-----------------------------------------------------------------------------
// Calculates a Jenkin's Encrypting and decrypting MPQ file data

ulong HashStringJenkins(string szFileName)
{
    ubyte[] pbFileName = cast(ubyte[])szFileName;
    char szLocFileName[0x108];
    size_t nLength = 0;
    uint primary_hash = 1;
    uint secondary_hash = 2;

    // Normalize the file name - convert to uppercase, and convert "/" to "\\".
    if(pbFileName !is null)
    {
        char* szTemp = szLocFileName.ptr;
        foreach(i, ref c; pbFileName)
            szTemp[i] = cast(char)AsciiToLowerTable[cast(size_t)c];

        nLength = szTemp - szLocFileName.ptr;
    }

    // Thanks Quantam for finding out what the algorithm is.
    // I am really getting old for reversing large chunks of assembly
    // that does hashing :-)
    hashlittle2(szLocFileName[0 .. nLength], secondary_hash, primary_hash);

    // Combine those 2 together
    return cast(ulong)primary_hash * cast(ulong)0x100000000U + cast(ulong)secondary_hash;
}