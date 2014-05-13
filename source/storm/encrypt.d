/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Encrypting/Decrypting MPQ data block
*/
module storm.encrypt;

import storm.hashing;
import storm.constants;
import std.path;

void EncryptMpqBlock(uint[] dataBlock, uint dwKey1)
{
    uint dwValue32;
    uint dwKey2 = 0xEEEEEEEE;

    // Encrypt the data block at array of DWORDs
    for(uint i = 0; i < dataBlock.length; i++)
    {
        // Modify the second key
        dwKey2 += StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)];

        dwValue32 = dataBlock[i];
        dataBlock[i] = dataBlock[i] ^ (dwKey1 + dwKey2);

        dwKey1 = ((~dwKey1 << 0x15) + 0x11111111) | (dwKey1 >> 0x0B);
        dwKey2 = dwValue32 + dwKey2 + (dwKey2 << 5) + 3;
    }
}

void DecryptMpqBlock(uint[] dataBlock, uint dwKey1)
{
    uint dwValue32;
    uint dwKey2 = 0xEEEEEEEE;

    // Decrypt the data block at array of DWORDs
    for(uint i = 0; i < dataBlock.length; i++)
    {
        // Modify the second key
        dwKey2 += StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)];
        
        dataBlock[i] = dataBlock[i] ^ (dwKey1 + dwKey2);
        dwValue32 = dataBlock[i];

        dwKey1 = ((~dwKey1 << 0x15) + 0x11111111) | (dwKey1 >> 0x0B);
        dwKey2 = dwValue32 + dwKey2 + (dwKey2 << 5) + 3;
    }
}

/**
 * Functions tries to get file decryption key. This comes from these facts
 *
 * - We know the decrypted value of the first uint in the encrypted data
 * - We know the decrypted value of the second uint (at least aproximately)
 * - There is only 256 variants of how the second key is modified
 *
 *  The first iteration of dwKey1 and dwKey2 is this:
 *
 *  dwKey2 = 0xEEEEEEEE + StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)]
 *  dwDecrypted0 = DataBlock[0] ^ (dwKey1 + dwKey2);
 *
 *  This means:
 *
 *  (dwKey1 + dwKey2) = DataBlock[0] ^ dwDecrypted0;
 *
 */
uint DetectFileKeyBySectorSize(uint[] EncryptedData, uint dwSectorSize, size_t dwDecrypted0)
{
    size_t dwDecrypted1Max = dwSectorSize + dwDecrypted0;
    uint[2] DataBlock;

    // We must have at least 2 DWORDs there to be able to decrypt something
    if(dwSectorSize < 0x08)
        return 0;

    // Get the value of the combined encryption key
    size_t dwKey1PlusKey2 = (EncryptedData[0] ^ dwDecrypted0) - 0xEEEEEEEE;

    // Try all 256 combinations of dwKey1
    for(uint i = 0; i < 0x100; i++)
    {
        uint dwSaveKey1;
        uint dwKey1 = cast(uint)dwKey1PlusKey2 - StormBuffer[MPQ_HASH_KEY2_MIX + i];
        uint dwKey2 = 0xEEEEEEEE;

        // Modify the second key and decrypt the first uint
        dwKey2 += StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)];
        DataBlock[0] = EncryptedData[0] ^ (dwKey1 + dwKey2);

        // Did we obtain the same value like dwDecrypted0?
        if(DataBlock[0] == dwDecrypted0)
        {
            // Save this key value. Increment by one because
            // we are decrypting sector offset table
            dwSaveKey1 = dwKey1 + 1;

            // Rotate both keys
            dwKey1 = ((~dwKey1 << 0x15) + 0x11111111) | (dwKey1 >> 0x0B);
            dwKey2 = DataBlock[0] + dwKey2 + (dwKey2 << 5) + 3;

            // Modify the second key again and decrypt the second uint
            dwKey2 += StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)];
            DataBlock[1] = EncryptedData[1] ^ (dwKey1 + dwKey2);

            // Now compare the results
            if(DataBlock[1] <= dwDecrypted1Max)
                return dwSaveKey1;
        }
    }

    // Key not found
    return 0;
}

/// Function tries to detect file encryption key based on expected file content
/// It is the same function like before, except that we know the value of the second uint
uint DetectFileKeyByKnownContent(uint[] EncryptedData, uint dwDecrypted0, uint dwDecrypted1)
{
    uint dwKey1PlusKey2;
    uint DataBlock[2];

    // Get the value of the combined encryption key
    dwKey1PlusKey2 = (EncryptedData[0] ^ dwDecrypted0) - 0xEEEEEEEE;

    // Try all 256 combinations of dwKey1
    for(uint i = 0; i < 0x100; i++)
    {
        uint dwSaveKey1;
        uint dwKey1 = dwKey1PlusKey2 - StormBuffer[MPQ_HASH_KEY2_MIX + i];
        uint dwKey2 = 0xEEEEEEEE;

        // Modify the second key and decrypt the first uint
        dwKey2 += StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)];
        DataBlock[0] = EncryptedData[0] ^ (dwKey1 + dwKey2);

        // Did we obtain the same value like dwDecrypted0?
        if(DataBlock[0] == dwDecrypted0)
        {
            // Save this key value
            dwSaveKey1 = dwKey1;

            // Rotate both keys
            dwKey1 = ((~dwKey1 << 0x15) + 0x11111111) | (dwKey1 >> 0x0B);
            dwKey2 = DataBlock[0] + dwKey2 + (dwKey2 << 5) + 3;

            // Modify the second key again and decrypt the second uint
            dwKey2 += StormBuffer[MPQ_HASH_KEY2_MIX + (dwKey1 & 0xFF)];
            DataBlock[1] = EncryptedData[1] ^ (dwKey1 + dwKey2);

            // Now compare the results
            if(DataBlock[1] == dwDecrypted1)
                return dwSaveKey1;
        }
    }

    // Key not found
    return 0;
}

uint DetectFileKeyByContent(uint[] pvEncryptedData, uint dwSectorSize, uint dwFileSize)
{
    uint dwFileKey;

    // Try to break the file encryption key as if it was a WAVE file
    if(dwSectorSize >= 0x0C)
    {
        dwFileKey = DetectFileKeyByKnownContent(pvEncryptedData, 0x46464952, dwFileSize - 8);
        if(dwFileKey != 0)
            return dwFileKey;
    }

    // Try to break the encryption key as if it was an EXE file
    if(dwSectorSize > 0x40)
    {
        dwFileKey = DetectFileKeyByKnownContent(pvEncryptedData, 0x00905A4D, 0x00000003);
        if(dwFileKey != 0)
            return dwFileKey;
    }

    // Try to break the encryption key as if it was a XML file
    if(dwSectorSize > 0x04)
    {
        dwFileKey = DetectFileKeyByKnownContent(pvEncryptedData, 0x6D783F3C, 0x6576206C);
        if(dwFileKey != 0)
            return dwFileKey;
    }

    // Not detected, sorry
    return 0;
}

uint DecryptFileKey(
    string szFileName,
    ulong MpqPos,
    uint dwFileSize,
    uint dwFlags)
{
    uint dwFileKey;

    // File key is calculated from plain name
    szFileName = baseName(szFileName);
    dwFileKey = HashString(szFileName, MPQ_HASH_FILE_KEY);

    // Fix the key, if needed
    if(dwFlags & MPQ_FILE_FIX_KEY)
        dwFileKey = (dwFileKey + cast(uint)MpqPos) ^ dwFileSize;

    // Return the key
    return dwFileKey;
}
