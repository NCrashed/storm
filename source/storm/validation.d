/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*
*   Handle validation functions
*/
module storm.validation;

import storm.mpq;
import storm.constants;
import tomcrypt.hash;
import std.algorithm;

private enum ID_MPQ_FILE = 0x46494c45;

TMPQArchive* IsValidMpqHandle(void* hMpq)
{
    TMPQArchive * ha = cast(TMPQArchive *)hMpq;
    
    return (ha !is null && ha.pHeader !is null && ha.pHeader.dwID == ID_MPQ) ? ha : null;
}

TMPQFile* IsValidFileHandle(void* hFile)
{
    TMPQFile * hf = cast(TMPQFile *)hFile;

    // Must not be null
    if(hf !is null && hf.dwMagic == ID_MPQ_FILE)
    {
        // Local file handle?
        if(hf.pStream !is null)
            return hf;

        // Also verify the MPQ handle within the file handle
        if(IsValidMpqHandle(hf.ha))
            return hf;
    }

    return null;
}

bool IsValidMD5(ubyte[] pbMd5)
{
    assert(pbMd5.length == MD5_DIGEST_SIZE, "Invalid size of md5 array!");
    ubyte BitSummary = 0;
    
    // The MD5 is considered invalid of it is zeroed
    BitSummary |= pbMd5[0x00] | pbMd5[0x01] | pbMd5[0x02] | pbMd5[0x03] | pbMd5[0x04] | pbMd5[0x05] | pbMd5[0x06] | pbMd5[0x07];
    BitSummary |= pbMd5[0x08] | pbMd5[0x09] | pbMd5[0x0A] | pbMd5[0x0B] | pbMd5[0x0C] | pbMd5[0x0D] | pbMd5[0x0E] | pbMd5[0x0F];
    return (BitSummary != 0);
}

bool VerifyDataBlockHash(ubyte[] pvDataBlock, ubyte[] expected_md5)
{
    hash_state md5_state;
    ubyte[MD5_DIGEST_SIZE] md5_digest;

    // Don't verify the block if the MD5 is not valid.
    if(!IsValidMD5(expected_md5))
        return true;

    // Calculate the MD5 of the data block
    md5_init(&md5_state);
    md5_process(&md5_state, pvDataBlock.ptr, pvDataBlock.length);
    md5_done(&md5_state, md5_digest.ptr);

    // Does the MD5's match?
    return md5_digest[].equal(expected_md5);
}

void CalculateDataBlockHash(ubyte[] pvDataBlock, ubyte[] md5_hash)
{
    hash_state md5_state;

    md5_init(&md5_state);
    md5_process(&md5_state, pvDataBlock.ptr, pvDataBlock.length);
    md5_done(&md5_state, md5_hash.ptr);
}
