/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
module storm.errors;

version(Posix)
{
    import core.stdc.errno;
    
    enum ERROR_SUCCESS                  = 0;
    enum ERROR_FILE_NOT_FOUND           = ENOENT;
    enum ERROR_ACCESS_DENIED            = EPERM;
    enum ERROR_INVALID_HANDLE           = EBADF;
    enum ERROR_NOT_ENOUGH_MEMORY        = ENOMEM;
    version(linux)
    {
        enum ERROR_NOT_SUPPORTED        = EOPNOTSUPP;
    } 
    else
    {
        enum ERROR_NOT_SUPPORTED        = ENOTSUP;
    }
    enum ERROR_INVALID_PARAMETER        = EINVAL;
    enum ERROR_DISK_FULL                = ENOSPC;
    enum ERROR_ALREADY_EXISTS           = EEXIST;
    enum ERROR_INSUFFICIENT_BUFFER      = ENOBUFS;
    enum ERROR_BAD_FORMAT               = 1000;        // No such error code under Linux
    enum ERROR_NO_MORE_FILES            = 1001;        // No such error code under Linux
    enum ERROR_HANDLE_EOF               = 1002;        // No such error code under Linux
    enum ERROR_CAN_NOT_COMPLETE         = 1003;        // No such error code under Linux
    enum ERROR_FILE_CORRUPT             = 1004;        // No such error code under Linux
    
    private int nLastError = ERROR_SUCCESS;
    
    void  SetLastError(int err)
    {
        nLastError = err;
    }
    
    int   GetLastError()
    {
        return nLastError;
    }
}
version(Windows)
{
    public import core.sys.windows.windows;
}