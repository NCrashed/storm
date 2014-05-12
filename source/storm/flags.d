/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.flags;

import storm.constants;

/// Default flags for (attributes) and (listfile)
uint GetDefaultSpecialFileFlags(uint dwFileSize, ushort wFormatVersion)
{
    // Fixed for format 1.0
    if(wFormatVersion == MPQ_FORMAT_VERSION_1)
        return MPQ_FILE_COMPRESS | MPQ_FILE_ENCRYPTED | MPQ_FILE_FIX_KEY;

    // Size-dependent for formats 2.0-4.0
    return (dwFileSize > 0x4000) ? (MPQ_FILE_COMPRESS | MPQ_FILE_SECTOR_CRC) : (MPQ_FILE_COMPRESS | MPQ_FILE_SINGLE_UNIT);
}