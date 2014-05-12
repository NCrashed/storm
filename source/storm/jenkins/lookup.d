/**
*   Copyright: © 2006 Bob Jenkins
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Bob Jenkins, Ladislav Zezula, NCrashed <ncrashed@gmail.com>
*/
/*
-------------------------------------------------------------------------------
lookup3.c, by Bob Jenkins, May 2006, Public Domain.

These are functions for producing 32-bit hashes for hash table lookup.
hashword(), hashlittle(), hashlittle2(), hashbig(), mix(), and final() 
are externally useful functions.  Routines to test the hash are included 
if SELF_TEST is defined.  You can use this free for any purpose.  It's in
the public domain.  It has no warranty.

You probably want to use hashlittle().  hashlittle() and hashbig()
hash byte arrays.  hashlittle() is is faster than hashbig() on
little-endian machines.  Intel and AMD are little-endian machines.
On second thought, you probably want hashlittle2(), which is identical to
hashlittle() except it returns two 32-bit hashes for the price of one.  
You could implement hashbig2() if you wanted but I haven't bothered here.

If you want to find a hash of, say, exactly 7 integers, do
  a = i1;  b = i2;  c = i3;
  mix(a,b,c);
  a += i4; b += i5; c += i6;
  mix(a,b,c);
  a += i7;
  final(a,b,c);
then use c as the hash value.  If you have a variable length array of
4-byte integers to hash, use hashword().  If you have a byte array (like
a character string), use hashlittle().  If you have several byte arrays, or
a mix of things, see the comments above hashlittle().  

Why is this so big?  I read 12 bytes at a time into 3 4-byte integers, 
then mix those integers.  This is fast (you can do a lot more thorough
mixing with 12*3 instructions on 3 integers than you can with 3 instructions
on 1 byte), but shoehorning those bytes into integers efficiently is messy.
-------------------------------------------------------------------------------
*/
module storm.jenkins.lookup;

/**
*   Hash a variable-length key into a 32-bit value
*   Params:
*     k         the key (the unaligned variable-length array of bytes)
*     initval   can be any 4-byte value
*   Returns a 32-bit value.  Every bit of the key affects every bit of
*   the return value.  Two keys differing by one or two bits will have
*   totally different hash values.
*   
*   The best hash table sizes are powers of 2.  There is no need to do
*   mod a prime (mod is sooo slow!).  If you need less than 32 bits,
*   use a bitmask.  For example, if you need only 10 bits, do
*     h = (h & hashmask(10));
*   In which case, the hash table should have hashsize(10) elements.
*   
*   If you are hashing n strings (ubyte **)k, do it like this:
*     for (i=0, h=0; i<n; ++i) h = hashlittle( k[i], len[i], h);
*   
*   By Bob Jenkins, 2006.  bob_jenkins@burtleburtle.net.  You may use this
*   code any way you wish, private, educational, or commercial.  It's free.
*   
*   Use for hash table lookup, or anything where one collision in 2^^32 is
*   acceptable.  Do NOT use for cryptographic purposes.
*/
uint hashlittle(const(ubyte)[] key, uint initval)
{
    uint a,b,c;                                          /* internal state */
    union U { const(ubyte)* ptr; size_t i; }             /* needed for Mac Powerbook G4 */
    U  u;     

    /* Set up the internal state */
    a = b = c = 0xdeadbeef + (cast(uint)key.length) + initval;

    u.ptr = key.ptr;
    version(LittleEndian)
    {
        if ((u.i & 0x3) == 0) 
        {
            size_t length = key.length;
            const(uint)*  k = cast(const(uint)*)key.ptr;         /* read 32-bit chunks */
            const(ubyte)* k8;
    
            /*------ all but last block: aligned reads and affect 32 bits of (a,b,c) */
            while (length > 12)
            {
                a += k[0];
                b += k[1];
                c += k[2];
                mix(a,b,c);
                length -= 12;
                k += 3;
            }
        
            /*----------------------------- handle the last (probably partial) block */
            /* 
             * "k[2]&0xffffff" actually reads beyond the end of the string, but
             * then masks off the part it's not allowed to read.  Because the
             * string is aligned, the masked-off tail is in the same word as the
             * rest of the string.  Every machine with memory protection I've seen
             * does it on word boundaries, so is OK with this.  But VALGRIND will
             * still catch it and complain.  The masking trick does make the hash
             * noticably faster for short strings (like English words).
             */
            version(VALGRIND) /* make valgrind happy */
            {
                k8 = cast(const(ubyte)*)k;
                switch(length)
                {
                    case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
                    case 11: c+=(cast(uint)k8[10])<<16; goto case 10; /* fall through */
                    case 10: c+=(cast(uint)k8[9])<<8; goto case 9;    /* fall through */
                    case 9 : c+=k8[8]; goto case 8;                   /* fall through */
                    case 8 : b+=k[1]; a+=k[0]; break;
                    case 7 : b+=(cast(uint)k8[6])<<16; goto case 6;   /* fall through */
                    case 6 : b+=(cast(uint)k8[5])<<8;  goto case 5;   /* fall through */
                    case 5 : b+=k8[4]; goto case 4;                   /* fall through */
                    case 4 : a+=k[0]; break;
                    case 3 : a+=(cast(uint)k8[2])<<16; goto case 2;   /* fall through */
                    case 2 : a+=(cast(uint)k8[1])<<8; goto case 1;    /* fall through */
                    case 1 : a+=k8[0]; break;
                    case 0 : return c;
                    default: return c;
                }
            
            } 
            else
            { 
                switch(length)
                {
                    case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
                    case 11: c+=k[2]&0xffffff; b+=k[1]; a+=k[0]; break;
                    case 10: c+=k[2]&0xffff; b+=k[1]; a+=k[0]; break;
                    case 9 : c+=k[2]&0xff; b+=k[1]; a+=k[0]; break;
                    case 8 : b+=k[1]; a+=k[0]; break;
                    case 7 : b+=k[1]&0xffffff; a+=k[0]; break;
                    case 6 : b+=k[1]&0xffff; a+=k[0]; break;
                    case 5 : b+=k[1]&0xff; a+=k[0]; break;
                    case 4 : a+=k[0]; break;
                    case 3 : a+=k[0]&0xffffff; break;
                    case 2 : a+=k[0]&0xffff; break;
                    case 1 : a+=k[0]&0xff; break;
                    case 0 : return c;              /* zero length strings require no mixing */
                    default: return c;
                }
            } /* !valgrind */
    
        } 
        else if( (u.i & 0x1) == 0 ) 
        {
            size_t length = key.length;
            const(ushort)* k = cast(const(ushort)*)key.ptr;         /* read 16-bit chunks */
            const(ubyte)*  k8;
        
            /*--------------- all but last block: aligned reads and different mixing */
            while (length > 12)
            {
                a += k[0] + ((cast(uint)k[1])<<16);
                b += k[2] + ((cast(uint)k[3])<<16);
                c += k[4] + ((cast(uint)k[5])<<16);
                mix(a,b,c);
                length -= 12;
                k += 6;
            }
        
            /*----------------------------- handle the last (probably partial) block */
            k8 = cast(const(ubyte*))k;
            switch(length)
            {
                case 12: c+=k[4]+((cast(uint)k[5])<<16);
                         b+=k[2]+((cast(uint)k[3])<<16);
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 11: c+=(cast(uint)k8[10])<<16; goto case 10;     /* fall through */
                case 10: c+=k[4];
                         b+=k[2]+((cast(uint)k[3])<<16);
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 9 : c+=k8[8]; goto case 8;                       /* fall through */
                case 8 : b+=k[2]+((cast(uint)k[3])<<16);
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 7 : b+=(cast(uint)k8[6])<<16; goto case 6;       /* fall through */
                case 6 : b+=k[2];
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 5 : b+=k8[4]; goto case 4;                      /* fall through */
                case 4 : a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 3 : a+=(cast(uint)k8[2])<<16; goto case 2;      /* fall through */
                case 2 : a+=k[0];
                         break;
                case 1 : a+=k8[0];
                         break;
                case 0 : return c;                     /* zero length requires no mixing */
                default: return c;
            }
    
        } 
        else
        {
            size_t length = key.length;
            const(ubyte)* k = cast(const(ubyte)*)key.ptr;
    
            /*--------------- all but the last block: affect some 32 bits of (a,b,c) */
            while (length > 12)
            {
                a += k[0];
                a += (cast(uint)k[1])<<8;
                a += (cast(uint)k[2])<<16;
                a += (cast(uint)k[3])<<24;
                b += k[4];
                b += (cast(uint)k[5])<<8;
                b += (cast(uint)k[6])<<16;
                b += (cast(uint)k[7])<<24;
                c += k[8];
                c += (cast(uint)k[9])<<8;
                c += (cast(uint)k[10])<<16;
                c += (cast(uint)k[11])<<24;
                mix(a,b,c);
                length -= 12;
                k += 12;
            }
    
            /*-------------------------------- last block: affect all 32 bits of (c) */
            switch(length)                   /* all the case statements fall through */
            {
                case 12: c+=(cast(uint)k[11])<<24; goto case 11;
                case 11: c+=(cast(uint)k[10])<<16; goto case 10;
                case 10: c+=(cast(uint)k[9])<<8; goto case 9;
                case 9 : c+=k[8]; goto case 8;
                case 8 : b+=(cast(uint)k[7])<<24; goto case 7;
                case 7 : b+=(cast(uint)k[6])<<16; goto case 6;
                case 6 : b+=(cast(uint)k[5])<<8; goto case 5;
                case 5 : b+=k[4]; goto case 4;
                case 4 : a+=(cast(uint)k[3])<<24; goto case 3;
                case 3 : a+=(cast(uint)k[2])<<16; goto case 2;
                case 2 : a+=(cast(uint)k[1])<<8; goto case 1;
                case 1 : a+=k[0];
                    break;
                case 0 : return c;
                default: return c;
            }
        }
    }
    else                        /* need to read the key one byte at a time */
    {    
        size_t length = key.ptr;
        const(ubyte)* k = cast(const(ubyte)*)key.ptr;

        /*--------------- all but the last block: affect some 32 bits of (a,b,c) */
        while (length > 12)
        {
            a += k[0];
            a += (cast(uint)k[1])<<8;
            a += (cast(uint)k[2])<<16;
            a += (cast(uint)k[3])<<24;
            b += k[4];
            b += (cast(uint)k[5])<<8;
            b += (cast(uint)k[6])<<16;
            b += (cast(uint)k[7])<<24;
            c += k[8];
            c += (cast(uint)k[9])<<8;
            c += (cast(uint)k[10])<<16;
            c += (cast(uint)k[11])<<24;
            mix(a,b,c);
            length -= 12;
            k += 12;
        }

        /*-------------------------------- last block: affect all 32 bits of (c) */
        switch(length)                   /* all the case statements fall through */
        {
            case 12: c+=(cast(uint)k[11])<<24; goto case 11;
            case 11: c+=(cast(uint)k[10])<<16; goto case 10;
            case 10: c+=(cast(uint)k[9])<<8; goto case 9;
            case 9 : c+=k[8]; goto case 8;
            case 8 : b+=(cast(uint)k[7])<<24; goto case 7;
            case 7 : b+=(cast(uint)k[6])<<16; goto case 6;
            case 6 : b+=(cast(uint)k[5])<<8; goto case 5;
            case 5 : b+=k[4]; goto case 4;
            case 4 : a+=(cast(uint)k[3])<<24; goto case 3;
            case 3 : a+=(cast(uint)k[2])<<16; goto case 2;
            case 2 : a+=(cast(uint)k[1])<<8; goto case 1;
            case 1 : a+=k[0];
                break;
            case 0 : return c;
            default: return c;
        }
    }

    mfinal(a,b,c);
    return c;  
}

/**
*   hashlittle2: return 2 32-bit hash values
*   
*   This is identical to hashlittle(), except it returns two 32-bit hash
*   values instead of just one.  This is good enough for hash table
*   lookup with 2^^64 buckets, or if you want a second hash if you're not
*   happy with the first, or if you want a probably-unique 64-bit ID for
*   the key.  pc is better mixed than pb, so use pc first.  If you want
*   a 64-bit value do something like "pc + (((uint64_t)pb)<<32)".
*
*   Params:
*       key     the key to hash
*       pc      IN: primary initval, OUT: primary hash 
*       pb      IN: secondary initval, OUT: secondary hash
*/
void hashlittle2(const(ubyte)[] key, ref uint pc, ref uint pb)
{
    uint a,b,c;                                          /* internal state */
    union U { const(ubyte)* ptr; size_t i; }             /* needed for Mac Powerbook G4 */
    U u;     

    /* Set up the internal state */
    a = b = c = 0xdeadbeef + (cast(uint)key.length) + pc;
    c += pb;

    u.ptr = key.ptr;
    version(LittleEndian)
    {
        if ((u.i & 0x3) == 0) 
        {
            size_t length = key.length;
            const(uint)* k = cast(const(uint)*)key.ptr;         /* read 32-bit chunks */
            const(ubyte)* k8;
        
            /*------ all but last block: aligned reads and affect 32 bits of (a,b,c) */
            while (length > 12)
            {
                a += k[0];
                b += k[1];
                c += k[2];
                mix(a,b,c);
                length -= 12;
                k += 3;
            }
        
            /*----------------------------- handle the last (probably partial) block */
            /* 
             * "k[2]&0xffffff" actually reads beyond the end of the string, but
             * then masks off the part it's not allowed to read.  Because the
             * string is aligned, the masked-off tail is in the same word as the
             * rest of the string.  Every machine with memory protection I've seen
             * does it on word boundaries, so is OK with this.  But VALGRIND will
             * still catch it and complain.  The masking trick does make the hash
             * noticably faster for short strings (like English words).
             */
            version(VALGRIND)
            {
                k8 = cast(const(ubyte)*)k;
                switch(length)
                {
                    case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
                    case 11: c+=(cast(uint)k8[10])<<16; goto case 10; /* fall through */
                    case 10: c+=(cast(uint)k8[9])<<8; goto case 9;    /* fall through */
                    case 9 : c+=k8[8]; goto case 8;                   /* fall through */
                    case 8 : b+=k[1]; a+=k[0]; break;
                    case 7 : b+=(cast(uint)k8[6])<<16; goto case 6;   /* fall through */
                    case 6 : b+=(cast(uint)k8[5])<<8; goto case 5;    /* fall through */
                    case 5 : b+=k8[4]; goto case 4;                   /* fall through */
                    case 4 : a+=k[0]; break;
                    case 3 : a+=(cast(uint)k8[2])<<16; goto case 2;   /* fall through */
                    case 2 : a+=(cast(uint)k8[1])<<8; goto case 1;    /* fall through */
                    case 1 : a+=k8[0]; break;
                    case 0 : pc=c; pb=b; return;  /* zero length strings require no mixing */
                    default: pc=c; pb=b; return;
                }
            }
            else /* make valgrind happy */
            {   
                switch(length)
                {
                    case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
                    case 11: c+=k[2]&0xffffff; b+=k[1]; a+=k[0]; break;
                    case 10: c+=k[2]&0xffff; b+=k[1]; a+=k[0]; break;
                    case 9 : c+=k[2]&0xff; b+=k[1]; a+=k[0]; break;
                    case 8 : b+=k[1]; a+=k[0]; break;
                    case 7 : b+=k[1]&0xffffff; a+=k[0]; break;
                    case 6 : b+=k[1]&0xffff; a+=k[0]; break;
                    case 5 : b+=k[1]&0xff; a+=k[0]; break;
                    case 4 : a+=k[0]; break;
                    case 3 : a+=k[0]&0xffffff; break;
                    case 2 : a+=k[0]&0xffff; break;
                    case 1 : a+=k[0]&0xff; break;
                    case 0 : pc=c; pb=b; return;  /* zero length strings require no mixing */
                    default: pc=c; pb=b; return;
                }

            } /* !valgrind */
        } 
        else if ((u.i & 0x1) == 0) 
        {
            size_t length = key.length;
            const(ushort)* k = cast(const(ushort)*)key.ptr;         /* read 16-bit chunks */
            const(ubyte)*  k8;
        
            /*--------------- all but last block: aligned reads and different mixing */
            while (length > 12)
            {
                a += k[0] + ((cast(uint)k[1])<<16);
                b += k[2] + ((cast(uint)k[3])<<16);
                c += k[4] + ((cast(uint)k[5])<<16);
                mix(a,b,c);
                length -= 12;
                k += 6;
            }
        
            /*----------------------------- handle the last (probably partial) block */
            k8 = cast(const(ubyte)*)k;
            switch(length)
            {
                case 12: c+=k[4]+((cast(uint)k[5])<<16);
                         b+=k[2]+((cast(uint)k[3])<<16);
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 11: c+=(cast(uint)k8[10])<<16; goto case 10;     /* fall through */
                case 10: c+=k[4];
                         b+=k[2]+((cast(uint)k[3])<<16);
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 9 : c+=k8[8]; goto case 8;                       /* fall through */
                case 8 : b+=k[2]+((cast(uint)k[3])<<16);
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 7 : b+=(cast(uint)k8[6])<<16; goto case 6;       /* fall through */
                case 6 : b+=k[2];
                         a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 5 : b+=k8[4]; goto case 4;                       /* fall through */
                case 4 : a+=k[0]+((cast(uint)k[1])<<16);
                         break;
                case 3 : a+=(cast(uint)k8[2])<<16; goto case 2;       /* fall through */
                case 2 : a+=k[0];
                         break;
                case 1 : a+=k8[0];
                         break;
                case 0 : pc=c; pb=b; return;  /* zero length strings require no mixing */
                default: pc=c; pb=b; return;
            }
        } 
        else /* need to read the key one byte at a time */
        {                        
            size_t length = key.length;
            const(ubyte)* k = cast(const(ubyte)*)key.ptr;
        
            /*--------------- all but the last block: affect some 32 bits of (a,b,c) */
            while (length > 12)
            {
                a += k[0];
                a += (cast(uint)k[1])<<8;
                a += (cast(uint)k[2])<<16;
                a += (cast(uint)k[3])<<24;
                b += k[4];
                b += (cast(uint)k[5])<<8;
                b += (cast(uint)k[6])<<16;
                b += (cast(uint)k[7])<<24;
                c += k[8];
                c += (cast(uint)k[9])<<8;
                c += (cast(uint)k[10])<<16;
                c += (cast(uint)k[11])<<24;
                mix(a,b,c);
                length -= 12;
                k += 12;
            }
        
            /*-------------------------------- last block: affect all 32 bits of (c) */
            switch(length)                   /* all the case statements fall through */
            {
                case 12: c+=(cast(uint)k[11])<<24; goto case 11;
                case 11: c+=(cast(uint)k[10])<<16; goto case 10;
                case 10: c+=(cast(uint)k[9])<<8;  goto case 9;
                case 9 : c+=k[8]; goto case 8;
                case 8 : b+=(cast(uint)k[7])<<24; goto case 7;
                case 7 : b+=(cast(uint)k[6])<<16; goto case 6;
                case 6 : b+=(cast(uint)k[5])<<8; goto case 5;
                case 5 : b+=k[4]; goto case 4;
                case 4 : a+=(cast(uint)k[3])<<24; goto case 3;
                case 3 : a+=(cast(uint)k[2])<<16; goto case 2;
                case 2 : a+=(cast(uint)k[1])<<8; goto case 1;
                case 1 : a+=k[0];
                         break;
                case 0 : pc=c; pb=b; return;  /* zero length strings require no mixing */
                default: pc=c; pb=b; return;
            }
        }
    }
    else /* need to read the key one byte at a time */
    {                        
        size_t length = key.length;
        const(ubyte*) k = cast(const(ubyte*))key.ptr;
    
        /*--------------- all but the last block: affect some 32 bits of (a,b,c) */
        while (length > 12)
        {
            a += k[0];
            a += (cast(uint)k[1])<<8;
            a += (cast(uint)k[2])<<16;
            a += (cast(uint)k[3])<<24;
            b += k[4];
            b += (cast(uint)k[5])<<8;
            b += (cast(uint)k[6])<<16;
            b += (cast(uint)k[7])<<24;
            c += k[8];
            c += (cast(uint)k[9])<<8;
            c += (cast(uint)k[10])<<16;
            c += (cast(uint)k[11])<<24;
            mix(a,b,c);
            length -= 12;
            k += 12;
        }
    
        /*-------------------------------- last block: affect all 32 bits of (c) */
        switch(length)                   /* all the case statements fall through */
        {
            case 12: c+=(cast(uint)k[11])<<24; goto case 11;
            case 11: c+=(cast(uint)k[10])<<16; goto case 10;
            case 10: c+=(cast(uint)k[9])<<8;  goto case 9;
            case 9 : c+=k[8]; goto case 8;
            case 8 : b+=(cast(uint)k[7])<<24; goto case 7;
            case 7 : b+=(cast(uint)k[6])<<16; goto case 6;
            case 6 : b+=(cast(uint)k[5])<<8; goto case 5;
            case 5 : b+=k[4]; goto case 4;
            case 4 : a+=(cast(uint)k[3])<<24; goto case 3;
            case 3 : a+=(cast(uint)k[2])<<16; goto case 2;
            case 2 : a+=(cast(uint)k[1])<<8; goto case 1;
            case 1 : a+=k[0];
                     break;
            case 0 : pc=c; pb=b; return;  /* zero length strings require no mixing */
            default: pc=c; pb=b; return;
        }
    }

    mfinal(a,b,c);
    pc=c; pb=b;
}

private:

import std.traits;

size_t hashsize(uint n) 
{
    return 1u << n;
}

size_t hashmask(uint n) 
{
    return hashsize(n)-1;
}

T rot(T)(T x, uint k)
    if(isIntegral!T)
{
    return ( x << k ) | (x >> (T.sizeof*8-k));
}

/*
-------------------------------------------------------------------------------
mix -- mix 3 32-bit values reversibly.

This is reversible, so any information in (a,b,c) before mix() is
still in (a,b,c) after mix().

If four pairs of (a,b,c) inputs are run through mix(), or through
mix() in reverse, there are at least 32 bits of the output that
are sometimes the same for one pair and different for another pair.
This was tested for:
* pairs that differed by one bit, by two bits, in any combination
  of top bits of (a,b,c), or in any combination of bottom bits of
  (a,b,c).
* "differ" is defined as +, -, ^, or ~^.  For + and -, I transformed
  the output delta to a Gray code (a^(a>>1)) so a string of 1's (as
  is commonly produced by subtraction) look like a single 1-bit
  difference.
* the base values were pseudorandom, all zero but one bit set, or 
  all zero plus a counter that starts at zero.

Some k values for my "a-=c; a^=rot(c,k); c+=b;" arrangement that
satisfy this are
    4  6  8 16 19  4
    9 15  3 18 27 15
   14  9  3  7 17  3
Well, "9 15 3 18 27 15" didn't quite get 32 bits diffing
for "differ" defined as + with a one-bit base and a two-bit delta.  I
used http://burtleburtle.net/bob/hash/avalanche.html to choose 
the operations, constants, and arrangements of the variables.

This does not achieve avalanche.  There are input bits of (a,b,c)
that fail to affect some output bits of (a,b,c), especially of a.  The
most thoroughly mixed value is c, but it doesn't really even achieve
avalanche in c.

This allows some parallelism.  Read-after-writes are good at doubling
the number of bits affected, so the goal of mixing pulls in the opposite
direction as the goal of parallelism.  I did what I could.  Rotates
seem to cost as much as shifts on every machine I could lay my hands
on, and rotates are much kinder to the top and bottom bits, so I used
rotates.
-------------------------------------------------------------------------------
*/
void mix(ref uint a, ref uint b, ref uint c)
{ 
  a -= c;  a ^= rot(c, 4);  c += b; 
  b -= a;  b ^= rot(a, 6);  a += c; 
  c -= b;  c ^= rot(b, 8);  b += a; 
  a -= c;  a ^= rot(c,16);  c += b; 
  b -= a;  b ^= rot(a,19);  a += c; 
  c -= b;  c ^= rot(b, 4);  b += a; 
}

/*
-------------------------------------------------------------------------------
mfinal -- final mixing of 3 32-bit values (a,b,c) into c

Pairs of (a,b,c) values differing in only a few bits will usually
produce values of c that look totally different.  This was tested for
* pairs that differed by one bit, by two bits, in any combination
  of top bits of (a,b,c), or in any combination of bottom bits of
  (a,b,c).
* "differ" is defined as +, -, ^, or ~^.  For + and -, I transformed
  the output delta to a Gray code (a^(a>>1)) so a string of 1's (as
  is commonly produced by subtraction) look like a single 1-bit
  difference.
* the base values were pseudorandom, all zero but one bit set, or 
  all zero plus a counter that starts at zero.

These constants passed:
 14 11 25 16 4 14 24
 12 14 25 16 4 14 24
and these came close:
  4  8 15 26 3 22 24
 10  8 15 26 3 22 24
 11  8 15 26 3 22 24
-------------------------------------------------------------------------------
*/
void mfinal(ref uint a, ref uint b, ref uint c) 
{ 
  c ^= b; c -= rot(b,14); 
  a ^= c; a -= rot(c,11); 
  b ^= a; b -= rot(a,25); 
  c ^= b; c -= rot(b,16); 
  a ^= c; a -= rot(c,4);  
  b ^= a; b -= rot(a,14); 
  c ^= b; c -= rot(b,24); 
}

/*
--------------------------------------------------------------------
 This works on all machines.  To be useful, it requires
 -- that the key be an array of uint's, and
 -- that the length be the number of uint's in the key

 The function hashword() is identical to hashlittle() on little-endian
 machines, and identical to hashbig() on big-endian machines,
 except that the length has to be measured in uint32_ts rather than in
 bytes.  hashlittle() is more complicated than hashword() only because
 hashlittle() has to dance around fitting the key bytes into registers.
--------------------------------------------------------------------
*/
uint hashword(
    const(uint)[] k,              /* the key, an array of uint values */
    uint         initval)         /* the previous hash, or an arbitrary value */
{
    uint a,b,c;

    /* Set up the internal state */
    a = b = c = 0xdeadbeef + ((cast(uint)k.length)<<2) + initval;

    /*------------------------------------------------- handle most of the key */
    while (k.length > 3)
    {
        a += k[0];
        b += k[1];
        c += k[2];
        mix(a,b,c);
        k = k[3 .. $];
    }

    /*------------------------------------------- handle the last 3 uint's */
    switch(k.length)                     /* all the case statements fall through */
    { 
        case 3 : c+=k[2]; goto case 2;
        case 2 : b+=k[1]; goto case 1;
        case 1 : a+=k[0];
            mfinal(a,b,c);
            goto case 0;
        case 0:     /* case 0: nothing left to add */
        default:
        break;
    }
    /*------------------------------------------------------ report the result */
    return c;
}

/*
--------------------------------------------------------------------
hashword2() -- same as hashword(), but take two seeds and return two
32-bit values.  pc and pb must both be nonnull, and *pc and *pb must
both be initialized with seeds.  If you pass in (*pb)==0, the output 
(*pc) will be the same as the return value from hashword().
--------------------------------------------------------------------
*/
void hashword2 (
    const(uint)[] k,                 /* the key, an array of uint values */
    ref uint      pc,                /* IN: seed OUT: primary hash value */
    ref uint      pb)                /* IN: more seed OUT: secondary hash value */
{
    uint a,b,c;

    /* Set up the internal state */
    a = b = c = 0xdeadbeef + (cast(uint)(k.length<<2)) + pc;
    c += pb;

    /*------------------------------------------------- handle most of the key */
    while (k.length > 3)
    {
        a += k[0];
        b += k[1];
        c += k[2];
        mix(a,b,c);
        k = k[3 .. $];
    }

    /*------------------------------------------- handle the last 3 uint's */
    switch(k.length)                     /* all the case statements fall through */
    { 
        case 3 : c+=k[2]; goto case 2;
        case 2 : b+=k[1]; goto case 1;
        case 1 : a+=k[0]; 
            mfinal(a,b,c);
            goto case 0;
        case 0:                         /* case 0: nothing left to add */
        default:
        break;
    }
    /*------------------------------------------------------ report the result */
    pc=c; pb=b;
}

/*
 * hashbig():
 * This is the same as hashword() on big-endian machines.  It is different
 * from hashlittle() on all machines.  hashbig() takes advantage of
 * big-endian byte ordering. 
 */
uint hashbig( const(ubyte)[] key, uint initval)
{
    uint a,b,c;
    union U { const(ubyte)* ptr; size_t i; } /* to cast key to (size_t) happily */
    U u;
    
    /* Set up the internal state */
    a = b = c = 0xdeadbeef + (cast(uint)key.length) + initval;

    u.ptr = key.ptr;
    version(BigEndian)
    {
        if ((u.i & 0x3) == 0) 
        {
            size_t length = key.length;
            const(uint)*k = cast(const(uint)*)key.ptr;         /* read 32-bit chunks */
            const ubyte  *k8;
        
            /*------ all but last block: aligned reads and affect 32 bits of (a,b,c) */
            while (length > 12)
            {
                a += k[0];
                b += k[1];
                c += k[2];
                mix(a,b,c);
                length -= 12;
                k += 3;
            }
        
            /*----------------------------- handle the last (probably partial) block */
            /* 
             * "k[2]<<8" actually reads beyond the end of the string, but
             * then shifts out the part it's not allowed to read.  Because the
             * string is aligned, the illegal read is in the same word as the
             * rest of the string.  Every machine with memory protection I've seen
             * does it on word boundaries, so is OK with this.  But VALGRIND will
             * still catch it and complain.  The masking trick does make the hash
             * noticably faster for short strings (like English words).
             */
            version(VALGRIND)  /* make valgrind happy */
            {
                k8 = cast(const(ubyte)*)k;
                switch(length)                   /* all the case statements fall through */
                {
                    case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
                    case 11: c+=(cast(uint)k8[10])<<8; goto case 10; /* fall through */
                    case 10: c+=(cast(uint)k8[9])<<16; goto case 9;  /* fall through */
                    case 9 : c+=(cast(uint)k8[8])<<24; goto case 8;  /* fall through */
                    case 8 : b+=k[1]; a+=k[0]; break;
                    case 7 : b+=(cast(uint)k8[6])<<8; goto case 6;   /* fall through */
                    case 6 : b+=(cast(uint)k8[5])<<16; goto case 5;  /* fall through */
                    case 5 : b+=(cast(uint)k8[4])<<24; goto case 4;  /* fall through */
                    case 4 : a+=k[0]; break;
                    case 3 : a+=(cast(uint)k8[2])<<8; goto case 2;   /* fall through */
                    case 2 : a+=(cast(uint)k8[1])<<16; goto case 1;  /* fall through */
                    case 1 : a+=(cast(uint)k8[0])<<24; break;
                    case 0 : return c;
                }
            } 
            else
            {  
                switch(length)
                {
                    case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
                    case 11: c+=k[2]&0xffffff00; b+=k[1]; a+=k[0]; break;
                    case 10: c+=k[2]&0xffff0000; b+=k[1]; a+=k[0]; break;
                    case 9 : c+=k[2]&0xff000000; b+=k[1]; a+=k[0]; break;
                    case 8 : b+=k[1]; a+=k[0]; break;
                    case 7 : b+=k[1]&0xffffff00; a+=k[0]; break;
                    case 6 : b+=k[1]&0xffff0000; a+=k[0]; break;
                    case 5 : b+=k[1]&0xff000000; a+=k[0]; break;
                    case 4 : a+=k[0]; break;
                    case 3 : a+=k[0]&0xffffff00; break;
                    case 2 : a+=k[0]&0xffff0000; break;
                    case 1 : a+=k[0]&0xff000000; break;
                    case 0 : return c;              /* zero length strings require no mixing */
                    default: return c;
                }
            } /* !VALGRIND */
    
        } 
        else /* need to read the key one byte at a time */
        {         
            size_t length = key.length;             
            const(ubyte)*k = cast(const(ubyte)*)key.ptr;
    
            /*--------------- all but the last block: affect some 32 bits of (a,b,c) */
            while (length > 12)
            {
                a += (cast(uint)k[0])<<24;
                a += (cast(uint)k[1])<<16;
                a += (cast(uint)k[2])<<8;
                a += (cast(uint)k[3]);
                b += (cast(uint)k[4])<<24;
                b += (cast(uint)k[5])<<16;
                b += (cast(uint)k[6])<<8;
                b += (cast(uint)k[7]);
                c += (cast(uint)k[8])<<24;
                c += (cast(uint)k[9])<<16;
                c += (cast(uint)k[10])<<8;
                c += (cast(uint)k[11]);
                mix(a,b,c);
                length -= 12;
                k += 12;
            }
    
            /*-------------------------------- last block: affect all 32 bits of (c) */
            switch(length)                   /* all the case statements fall through */
            {
                case 12: c+=k[11];  goto case 11;
                case 11: c+=(cast(uint)k[10])<<8; goto case 10;
                case 10: c+=(cast(uint)k[9])<<16; goto case 9;
                case 9 : c+=(cast(uint)k[8])<<24; goto case 8;
                case 8 : b+=k[7]; goto case 7;
                case 7 : b+=(cast(uint)k[6])<<8; goto case 6;
                case 6 : b+=(cast(uint)k[5])<<16; goto case 5;
                case 5 : b+=(cast(uint)k[4])<<24; goto case 4;
                case 4 : a+=k[3]; goto case 3;
                case 3 : a+=(cast(uint)k[2])<<8; goto case 2;
                case 2 : a+=(cast(uint)k[1])<<16; goto case 1;
                case 1 : a+=(cast(uint)k[0])<<24;
                         break;
                case 0 : return c;
                default: return c;
            }
        }
    } 
    else /* need to read the key one byte at a time */
    {                     
        size_t length = key.length;   
        const(ubyte)*k = cast(const(ubyte)*)key.ptr;

        /*--------------- all but the last block: affect some 32 bits of (a,b,c) */
        while (length > 12)
        {
            a += (cast(uint)k[0])<<24;
            a += (cast(uint)k[1])<<16;
            a += (cast(uint)k[2])<<8;
            a += (cast(uint)k[3]);
            b += (cast(uint)k[4])<<24;
            b += (cast(uint)k[5])<<16;
            b += (cast(uint)k[6])<<8;
            b += (cast(uint)k[7]);
            c += (cast(uint)k[8])<<24;
            c += (cast(uint)k[9])<<16;
            c += (cast(uint)k[10])<<8;
            c += (cast(uint)k[11]);
            mix(a,b,c);
            length -= 12;
            k += 12;
        }

        /*-------------------------------- last block: affect all 32 bits of (c) */
        switch(length)                   /* all the case statements fall through */
        {
            case 12: c+=k[11];  goto case 11;
            case 11: c+=(cast(uint)k[10])<<8; goto case 10;
            case 10: c+=(cast(uint)k[9])<<16; goto case 9;
            case 9 : c+=(cast(uint)k[8])<<24; goto case 8;
            case 8 : b+=k[7]; goto case 7;
            case 7 : b+=(cast(uint)k[6])<<8; goto case 6;
            case 6 : b+=(cast(uint)k[5])<<16; goto case 5;
            case 5 : b+=(cast(uint)k[4])<<24; goto case 4;
            case 4 : a+=k[3]; goto case 3;
            case 3 : a+=(cast(uint)k[2])<<8; goto case 2;
            case 2 : a+=(cast(uint)k[1])<<16; goto case 1;
            case 1 : a+=(cast(uint)k[0])<<24;
                     break;
            case 0 : return c;
            default: return c;
        }
    }
    
    mfinal(a,b,c);
    return c;
}

version(unittest)
{
    import std.datetime;
    import std.stdio;
    
    /* used for timings */
    void driver1()
    {
        ubyte[256] buf;
        uint i;
        uint h=0;
        StopWatch sw;
    
        sw.start();
        for (i=0; i<256; ++i) buf[i] = 'x';
        for (i=0; i<1; ++i) 
        {
            h = hashlittle(buf[i .. i+1],h);
        }
        sw.stop();
        
        writefln("time %s %.8x", sw.peek.msecs, h); 
    }
    
    /* check that every input bit changes every output bit half the time */
    enum HASHSTATE = 1;
    enum HASHLEN   = 1;
    enum MAXPAIR   = 60;
    enum MAXLEN    = 70;
    
    void driver2()
    {
        ubyte[MAXLEN+1] qa;
        ubyte[MAXLEN+2] qb;
        ubyte* a = qa.ptr;
        ubyte* b = qb.ptr;
        
        uint[HASHSTATE] c, d;
        uint i=0, j=0, k, l, m=0, z;
        
        uint[HASHSTATE] e,f,g,h;
        uint[HASHSTATE] x,y;
        uint hlen;
    
        writefln("No more than %s trials should ever be needed", MAXPAIR/2);
        for (hlen=0; hlen < MAXLEN; ++hlen)
        {
            z=0;
            for (i=0; i<hlen; ++i)  /*----------------------- for each input byte, */
            {
                for (j=0; j<8; ++j)   /*------------------------ for each input bit, */
                {
                    for (m=1; m<8; ++m) /*------------ for serveral possible initvals, */
                    {
                        for (l=0; l<HASHSTATE; ++l)
                            e[l]=f[l]=g[l]=h[l]=x[l]=y[l]=~(cast(uint)0);
    
                        /*---- check that every output bit is affected by that input bit */
                        for (k=0; k<MAXPAIR; k+=2)
                        { 
                            uint finished=1;
                            /* keys have one bit different */
                            for (l=0; l<hlen+1; ++l) {a[l] = b[l] = cast(ubyte)0;}
                            /* have a and b be two keys differing in only one bit */
                            a[i] ^= (k<<j);
                            a[i] ^= (k>>(8-j));
                            c[0] = hashlittle(a[0 .. hlen], m);
                            b[i] ^= ((k+1)<<j);
                            b[i] ^= ((k+1)>>(8-j));
                            d[0] = hashlittle(b[0 .. hlen], m);
                            /* check every bit is 1, 0, set, and not set at least once */
                            for (l=0; l<HASHSTATE; ++l)
                            {
                                e[l] &= (c[l]^d[l]);
                                f[l] &= ~(c[l]^d[l]);
                                g[l] &= c[l];
                                h[l] &= ~c[l];
                                x[l] &= d[l];
                                y[l] &= ~d[l];
                                if (e[l]|f[l]|g[l]|h[l]|x[l]|y[l]) finished=0;
                            }
                            if (finished) break;
                        }
                        
                        if (k>z) z=k;
                        if (k==MAXPAIR) 
                        {
                            write("Some bit didn't change: ");
                            writef("%.8x %.8x %.8x %.8x %.8x %.8x  ",
                                e[0],f[0],g[0],h[0],x[0],y[0]);
                            writefln("i %s j %s m %s len %s", i, j, m, hlen);
                        }
                        if (z==MAXPAIR) goto done;
                    }
                }
            }
            done:
            if (z < MAXPAIR)
            {
                writef("Mix success  %2s bytes  %2s initvals  ",i,m);
                writefln("required  %s  trials", z/2);
            }
        }
        writeln;
    }
    
    /* Check for reading beyond the end of the buffer and alignment problems */
    void driver3()
    {
        ubyte[MAXLEN+20] buf;
        ubyte* b;
        uint len;
        ubyte[] q = cast(ubyte[])"This is the time for all good men to come to the aid of their country...";
        uint h;
        ubyte[] qq = cast(ubyte[])"xThis is the time for all good men to come to the aid of their country...";
        uint i;
        ubyte[] qqq = cast(ubyte[])"xxThis is the time for all good men to come to the aid of their country...";
        uint j;
        ubyte[] qqqq = cast(ubyte[])"xxxThis is the time for all good men to come to the aid of their country...";
        uint _ref,x,y;
        ubyte* p;
        
        writeln("Endianness.  These lines should all be the same (for values filled in):");
        size_t nl = q.length/4;
        writefln("%.8x                            %.8x                            %.8x",
             hashword((cast(uint[])q)[0 .. nl], 13),
             hashword((cast(uint[])q)[0 .. nl-1], 13),
             hashword((cast(uint[])q)[0 .. nl-2], 13));
        p = q.ptr; nl = q.length;
        writefln("%.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x",
             hashlittle(p[0 .. nl  ], 13),  hashlittle(p[0 .. nl-1], 13),
             hashlittle(p[0 .. nl-2], 13),  hashlittle(p[0 .. nl-3], 13),
             hashlittle(p[0 .. nl-4], 13),  hashlittle(p[0 .. nl-5], 13),
             hashlittle(p[0 .. nl-6], 13),  hashlittle(p[0 .. nl-6], 13),
             hashlittle(p[0 .. nl-8], 13),  hashlittle(p[0 .. nl-9], 13),
             hashlittle(p[0 .. nl-10], 13), hashlittle(p[0 .. nl-11], 13));
        p = &qq[1];
        writefln("%.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x",
             hashlittle(p[0 .. nl  ], 13),  hashlittle(p[0 .. nl-1], 13),
             hashlittle(p[0 .. nl-2], 13),  hashlittle(p[0 .. nl-3], 13),
             hashlittle(p[0 .. nl-4], 13),  hashlittle(p[0 .. nl-5], 13),
             hashlittle(p[0 .. nl-6], 13),  hashlittle(p[0 .. nl-6], 13),
             hashlittle(p[0 .. nl-8], 13),  hashlittle(p[0 .. nl-9], 13),
             hashlittle(p[0 .. nl-10], 13), hashlittle(p[0 .. nl-11], 13));
        p = &qqq[2];
        writefln("%.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x",
             hashlittle(p[0 .. nl  ], 13),  hashlittle(p[0 .. nl-1], 13),
             hashlittle(p[0 .. nl-2], 13),  hashlittle(p[0 .. nl-3], 13),
             hashlittle(p[0 .. nl-4], 13),  hashlittle(p[0 .. nl-5], 13),
             hashlittle(p[0 .. nl-6], 13),  hashlittle(p[0 .. nl-6], 13),
             hashlittle(p[0 .. nl-8], 13),  hashlittle(p[0 .. nl-9], 13),
             hashlittle(p[0 .. nl-10], 13), hashlittle(p[0 .. nl-11], 13));
        p = &qqqq[3];
        writefln("%.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x",
             hashlittle(p[0 .. nl  ], 13),  hashlittle(p[0 .. nl-1], 13),
             hashlittle(p[0 .. nl-2], 13),  hashlittle(p[0 .. nl-3], 13),
             hashlittle(p[0 .. nl-4], 13),  hashlittle(p[0 .. nl-5], 13),
             hashlittle(p[0 .. nl-6], 13),  hashlittle(p[0 .. nl-6], 13),
             hashlittle(p[0 .. nl-8], 13),  hashlittle(p[0 .. nl-9], 13),
             hashlittle(p[0 .. nl-10], 13), hashlittle(p[0 .. nl-11], 13));
        writeln;
    
        /* check that hashlittle2 and hashlittle produce the same results */
        i=47; j=0;
        hashlittle2(q, i, j);
        if (hashlittle(q, 47) != i)
            writeln("hashlittle2 and hashlittle mismatch");
    
        /* check that hashword2 and hashword produce the same results */
        len = 0xdeadbeef;
        i=47, j=0;
        hashword2((&len)[0 .. 1], i, j);
        if (hashword((&len)[0 .. 1], 47) != i)
            writefln("hashword2 and hashword mismatch %x %x", 
                i, hashword((&len)[0 .. 1], 47));
    
        /* check hashlittle doesn't read before or after the ends of the string */
        for (h=0, b=buf.ptr+1; h<8; ++h, ++b)
        {
            for (i=0; i<MAXLEN; ++i)
            {
                len = i;
                for (j=0; j<i; ++j) *(b+j)=0;
    
                /* these should all be equal */
                _ref = hashlittle(b[0 .. len], cast(uint)1);
                *(b+i)=cast(ubyte)~0;
                ubyte* b2 = b-1; *b2=cast(ubyte)~0;
                
                x = hashlittle(b[0 .. len], cast(uint)1);
                y = hashlittle(b[0 .. len], cast(uint)1);
                if ((_ref != x) || (_ref != y)) 
                {
                    writefln("alignment error: %.8x %.8x %.8x %d %d",_ref,x,y,
                        h, i);
                }
            }
        }
    }
    
    /* check for problems with nulls */
    void driver4()
    {
        ubyte[1] buf;
        uint h,i;
        uint[HASHSTATE] state;
        
        
        buf[0] = 255;
        for (i=0; i<HASHSTATE; ++i) state[i] = 1;
        writeln("These should all be different");
        for (i=0, h=0; i<8; ++i)
        {
            h = hashlittle([], h);
            writefln("%s  0-byte strings, hash is  %.8x", i, h);
        }
    }
    
    void driver5()
    {
        uint b,c;
        b=0, c=0, hashlittle2(cast(ubyte[])"", c, b);
        writefln("hash is %.8x %.8x", c, b);   /* deadbeef deadbeef */
        b=0xdeadbeef, c=0, hashlittle2(cast(ubyte[])"", c, b);
        writefln("hash is %.8x %.8x", c, b);   /* bd5b7dde deadbeef */
        b=0xdeadbeef, c=0xdeadbeef, hashlittle2(cast(ubyte[])"", c, b);
        writefln("hash is %.8x %.8x", c, b);   /* 9c093ccd bd5b7dde */
        b=0, c=0, hashlittle2(cast(ubyte[])"Four score and seven years ago", c, b);
        writefln("hash is %.8x %.8x", c, b);   /* 17770551 ce7226e6 */
        b=1, c=0, hashlittle2(cast(ubyte[])"Four score and seven years ago", c, b);
        writefln("hash is %.8x %.8x", c, b);   /* e3607cae bd371de4 */
        b=0, c=1, hashlittle2(cast(ubyte[])"Four score and seven years ago", c, b);
        writefln("hash is %.8x %.8x", c, b);   /* cd628161 6cbea4b3 */
        c = hashlittle(cast(ubyte[])"Four score and seven years ago", 0);
        writefln("hash is %.8x", c);   /* 17770551 */
        c = hashlittle(cast(ubyte[])"Four score and seven years ago", 1);
        writefln("hash is %.8x", c);   /* cd628161 */
    }
    
    
    unittest
    {
        driver1();   /* test that the key is hashed: used for timings */
        driver2();   /* test that whole key is hashed thoroughly */
        driver3();   /* test that nothing but the key is hashed */
        driver4();   /* test hashing multiple buffers (all buffers are null) */
        driver5();   /* test the hash against known vectors */
    }

}