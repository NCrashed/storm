/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
/// Temporary file for small things that don't have any other place for now
module storm.miscs;

/// Hashing function
alias HASH_STRING = uint function(string fileName, uint hashType);