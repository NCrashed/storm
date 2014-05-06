/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.callback;

// Values for compact callback
/// Checking archive (dwParam1 = current, dwParam2 = total)
enum CB_CHECKING_FILES                 = 1;  
/// Checking hash table (dwParam1 = current, dwParam2 = total)
enum CCB_CHECKING_HASH_TABLE           = 2;  
/// Copying non-MPQ data: No params used
enum CCB_COPYING_NON_MPQ_DATA          = 3;  
/// Compacting archive (dwParam1 = current, dwParam2 = total)
enum CCB_COMPACTING_FILES              = 4;  
/// Closing archive: No params used
enum CCB_CLOSING_ARCHIVE               = 5;  

extern(Windows)
{
    alias SFILE_DOWNLOAD_CALLBACK = void function(void * pvUserData, ulong ByteOffset, uint dwTotalBytes);
    alias SFILE_ADDFILE_CALLBACK  = void function(void * pvUserData, uint dwBytesWritten, uint dwTotalBytes, bool bFinalCall);
    alias SFILE_COMPACT_CALLBACK  = void function(void * pvUserData, uint dwWorkType, ulong BytesProcessed, ulong TotalBytes);
}

alias LCID = uint;