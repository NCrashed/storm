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