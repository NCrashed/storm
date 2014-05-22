/**
*   Copyright: © 1999-2014 Ladislav Zezula
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: Ladislav Zezula, ShadowFlare <BlakFlare@hotmail.com>, NCrashed <ncrashed@gmail.com>
*
*   This module contains implementation of adpcm decompression method used by
*   Storm.dll to decompress WAVE files. Thanks to Tom Amigo for releasing
*   his sources. 
*/
module storm.adpcm;

enum MAX_ADPCM_CHANNEL_COUNT   = 2;
enum INITIAL_ADPCM_STEP_INDEX  = 0x2C;

size_t compressADPCM(ubyte[] outBuffer, ubyte[] inBuffer, int channelCount, int CompressionLevel)
{
    auto outputStream = new TADPCMStream(outBuffer);      // The output stream
    auto inputStream = new TADPCMStream(inBuffer);        // The input stream
    ubyte BitShift = cast(ubyte)(CompressionLevel - 1);
    short[MAX_ADPCM_CHANNEL_COUNT] PredictedSamples;// Predicted samples for each channel
    short[MAX_ADPCM_CHANNEL_COUNT] StepIndexes;     // Step indexes for each channel
    short InputSample;                              // Input sample for the current channel
    int TotalStepSize;
    int ChannelIndex;
    int AbsDifference;
    int Difference;
    int MaxBitMask;
    int StepSize;

//  _tprintf(_T("== CMPR Started ==============\n"));

    // First byte in the output stream contains zero. The second one contains the compression level
    outputStream.writeByteSample(0);
    if(!outputStream.writeByteSample(BitShift))
        return 2;

    // Set the initial step index for each channel
    StepIndexes[0] = StepIndexes[1] = INITIAL_ADPCM_STEP_INDEX;

    // Next, InitialSample value for each channel follows
    for(int i = 0; i < channelCount; i++)
    {
        // Get the initial sample from the input stream
        if(!inputStream.readWordSample(InputSample))
            return outputStream.lengthProcessed(outBuffer);

        // Store the initial sample to our sample array
        PredictedSamples[i] = InputSample;

        // Also store the loaded sample to the output stream
        if(!outputStream.writeWordSample(InputSample))
            return outputStream.lengthProcessed(outBuffer);
    }

    // Get the initial index
    ChannelIndex = channelCount - 1;
    
    // Now keep reading the input data as long as there is something in the input buffer
    while(inputStream.readWordSample(InputSample))
    {
        int EncodedSample = 0;

        // If we have two channels, we need to flip the channel index
        ChannelIndex = (ChannelIndex + 1) % channelCount;

        // Get the difference from the previous sample.
        // If the difference is negative, set the sign bit to the encoded sample
        AbsDifference = InputSample - PredictedSamples[ChannelIndex];
        if(AbsDifference < 0)
        {
            AbsDifference = -AbsDifference;
            EncodedSample |= 0x40;
        }

        // If the difference is too low (higher that difference treshold),
        // write a step index modifier marker
        StepSize = stepSizeTable[StepIndexes[ChannelIndex]];
        if(AbsDifference < (StepSize >> CompressionLevel))
        {
            if(StepIndexes[ChannelIndex] != 0)
                StepIndexes[ChannelIndex]--;
            
            outputStream.writeByteSample(0x80);
        }
        else
        {
            // If the difference is too high, write marker that
            // indicates increase in step size
            while(AbsDifference > (StepSize << 1))
            {
                if(StepIndexes[ChannelIndex] >= 0x58)
                    break;

                // Modify the step index
                StepIndexes[ChannelIndex] += 8;
                if(StepIndexes[ChannelIndex] > 0x58)
                    StepIndexes[ChannelIndex] = 0x58;

                // Write the "modify step index" marker
                StepSize = stepSizeTable[StepIndexes[ChannelIndex]];
                outputStream.writeByteSample(0x81);
            }

            // Get the limit bit value
            MaxBitMask = (1 << (BitShift - 1));
            MaxBitMask = (MaxBitMask > 0x20) ? 0x20 : MaxBitMask;
            Difference = StepSize >> BitShift;
            TotalStepSize = 0;

            for(int BitVal = 0x01; BitVal <= MaxBitMask; BitVal <<= 1)
            {
                if((TotalStepSize + StepSize) <= AbsDifference)
                {
                    TotalStepSize += StepSize;
                    EncodedSample |= BitVal;
                }
                StepSize >>= 1;
            }

            PredictedSamples[ChannelIndex] = cast(short)UpdatePredictedSample(PredictedSamples[ChannelIndex],
                                                                          EncodedSample,
                                                                          Difference + TotalStepSize);
            // Write the encoded sample to the output stream
            if(!outputStream.writeByteSample(cast(ubyte)EncodedSample))
                break;
            
            // Calculates the step index to use for the next encode
            StepIndexes[ChannelIndex] = GetNextStepIndex(StepIndexes[ChannelIndex], EncodedSample);
        }
    }

//  _tprintf(_T("== CMPR Ended ================\n"));
    return outputStream.lengthProcessed(outBuffer);
}

size_t decompressADPCM(ubyte[] outBuffer, ubyte[] inBuffer, int channelCount)
{
    auto outputStream = new TADPCMStream(outBuffer);      // The output stream
    auto inputStream = new TADPCMStream(inBuffer);        // The input stream
    ubyte EncodedSample;
    ubyte BitShift;
    short[MAX_ADPCM_CHANNEL_COUNT] PredictedSamples;    // Predicted sample for each channel
    short[MAX_ADPCM_CHANNEL_COUNT] StepIndexes;         // Predicted step index for each channel
    int ChannelIndex;                                   // Current channel index

    // Initialize the StepIndex for each channel
    StepIndexes[0] = StepIndexes[1] = INITIAL_ADPCM_STEP_INDEX;

//  _tprintf(_T("== DCMP Started ==============\n"));

    // The first byte is always zero, the second one contains bit shift (compression level - 1)
    inputStream.readByteSample(BitShift);
    inputStream.readByteSample(BitShift);
//  _tprintf(_T("DCMP: BitShift = %u\n"), (uint)(ubyte)BitShift);

    // Next, InitialSample value for each channel follows
    for(int i = 0; i < channelCount; i++)
    {
        // Get the initial sample from the input stream
        short InitialSample;

        // Attempt to read the initial sample
        if(!inputStream.readWordSample(InitialSample))
            return outputStream.lengthProcessed(outBuffer);

//      _tprintf(_T("DCMP: Loaded InitialSample[%u]: %04X\n"), i, (uint)(unsigned short)InitialSample);

        // Store the initial sample to our sample array
        PredictedSamples[i] = InitialSample;

        // Also store the loaded sample to the output stream
        if(!outputStream.writeWordSample(InitialSample))
            return outputStream.lengthProcessed(outBuffer);
    }

    // Get the initial index
    ChannelIndex = channelCount - 1;

    // Keep reading as long as there is something in the input buffer
    while(inputStream.readByteSample(EncodedSample))
    {
//      _tprintf(_T("DCMP: Loaded Encoded Sample: %02X\n"), (uint)(ubyte)EncodedSample);

        // If we have two channels, we need to flip the channel index
        ChannelIndex = (ChannelIndex + 1) % channelCount;

        if(EncodedSample == 0x80)
        {
            if(StepIndexes[ChannelIndex] != 0)
                StepIndexes[ChannelIndex]--;

//          _tprintf(_T("DCMP: Writing Decoded Sample: %04lX\n"), (uint)(unsigned short)PredictedSamples[ChannelIndex]);
            if(!outputStream.writeWordSample(PredictedSamples[ChannelIndex]))
                return outputStream.lengthProcessed(outBuffer);
        }
        else if(EncodedSample == 0x81)
        {
            // Modify the step index
            StepIndexes[ChannelIndex] += 8;
            if(StepIndexes[ChannelIndex] > 0x58)
                StepIndexes[ChannelIndex] = 0x58;

//          _tprintf(_T("DCMP: New value of StepIndex: %04lX\n"), (uint)(unsigned short)StepIndexes[ChannelIndex]);

            // Next pass, keep going on the same channel
            ChannelIndex = (ChannelIndex + 1) % channelCount;
        }
        else
        {
            int StepIndex = StepIndexes[ChannelIndex];
            int StepSize = stepSizeTable[StepIndex];

            // Encode one sample
            PredictedSamples[ChannelIndex] = cast(short)DecodeSample(PredictedSamples[ChannelIndex],
                                                                     EncodedSample, 
                                                                     StepSize,
                                                                     StepSize >> BitShift);

//          _tprintf(_T("DCMP: Writing decoded sample: %04X\n"), (uint)(unsigned short)PredictedSamples[ChannelIndex]);

            // Write the decoded sample to the output stream
            if(!outputStream.writeWordSample(PredictedSamples[ChannelIndex]))
                break;

            // Calculates the step index to use for the next encode
            StepIndexes[ChannelIndex] = GetNextStepIndex(StepIndex, EncodedSample);
//          _tprintf(_T("DCMP: New step index: %04X\n"), (uint)(unsigned short)StepIndexes[ChannelIndex]);
        }
    }

//  _tprintf(_T("DCMP: Total length written: %u\n"), (uint)outputStream.lengthProcessed(pvOutBuffer));
//  _tprintf(_T("== DCMP Ended ================\n"));

    // Return total bytes written since beginning of the output buffer
    return outputStream.lengthProcessed(outBuffer);
}


private:

//-----------------------------------------------------------------------------
// Tables necessary dor decompression

immutable int[] nextStepTable =
[
    -1, 0, -1, 4, -1, 2, -1, 6,
    -1, 1, -1, 5, -1, 3, -1, 7,
    -1, 1, -1, 5, -1, 3, -1, 7,
    -1, 2, -1, 4, -1, 6, -1, 8
];

immutable int[] stepSizeTable =
[
        7,     8,     9,    10,     11,    12,    13,    14,
       16,    17,    19,    21,     23,    25,    28,    31,
       34,    37,    41,    45,     50,    55,    60,    66,
       73,    80,    88,    97,    107,   118,   130,   143,
      157,   173,   190,   209,    230,   253,   279,   307,
      337,   371,   408,   449,    494,   544,   598,   658,
      724,   796,   876,   963,   1060,  1166,  1282,  1411,
     1552,  1707,  1878,  2066,   2272,  2499,  2749,  3024,
     3327,  3660,  4026,  4428,   4871,  5358,  5894,  6484,
     7132,  7845,  8630,  9493,  10442, 11487, 12635, 13899,
     15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
     32767
];

//-----------------------------------------------------------------------------
// Helper class for writing output ADPCM data

class TADPCMStream
{
    this(ubyte[] buffer)
    {
        this.buffer = buffer;
    }

    bool readByteSample(ref ubyte byteSample)
    {
        // Check if there is enough space in the buffer
        if(buffer.length == 0)
            return false;

        byteSample = buffer[0];
        buffer = buffer[1 .. $];
        
        return true;
    }

    bool writeByteSample(ubyte byteSample)
    {
        // Check if there is enough space in the buffer
        if(buffer.length == 0)
            return false;

        buffer[0] = byteSample;
        buffer = buffer[1 .. $];

        return true;
    }

    bool readWordSample(ref short oneSample)
    {
        // Check if we have enough space in the output buffer
        if(buffer.length < short.sizeof)
            return false;

        // Write the sample
        oneSample = cast(short)(buffer[0] + (buffer[1] << 0x08));
        buffer = buffer[short.sizeof .. $];
        
        return true;
    }

    bool writeWordSample(short OneSample)
    {
        // Check if we have enough space in the output buffer
        if(buffer.length < short.sizeof)
            return false;

        // Write the sample
        buffer[0] = cast(ubyte)(OneSample & 0xFF);
        buffer[1] = cast(ubyte)(OneSample >> 0x08);
        buffer = buffer[short.sizeof .. $];
        
        return true;
    }

    size_t lengthProcessed(ubyte[] origBuffer)
    {
        return origBuffer.length - buffer.length;
    }

    private ubyte[] buffer;
}               

//----------------------------------------------------------------------------
// Local functions

short GetNextStepIndex(int StepIndex, uint EncodedSample)
{
    // Get the next step index
    StepIndex = StepIndex + nextStepTable[EncodedSample & 0x1F];

    // Don't make the step index overflow
    if(StepIndex < 0)
        StepIndex = 0;
    else if(StepIndex > 88)
        StepIndex = 88;

    return cast(short)StepIndex;
}

int UpdatePredictedSample(int PredictedSample, int EncodedSample, int Difference)
{
    // Is the sign bit set?
    if(EncodedSample & 0x40)
    {
        PredictedSample -= Difference;
        if(PredictedSample <= -32768)
            PredictedSample = -32768;
    }
    else
    {
        PredictedSample += Difference;
        if(PredictedSample >= 32767)
            PredictedSample = 32767;
    }

    return PredictedSample;
}

int DecodeSample(int PredictedSample, int EncodedSample, int StepSize, int Difference)
{
    if(EncodedSample & 0x01)
        Difference += (StepSize >> 0);

    if(EncodedSample & 0x02)
        Difference += (StepSize >> 1);

    if(EncodedSample & 0x04)
        Difference += (StepSize >> 2);

    if(EncodedSample & 0x08)
        Difference += (StepSize >> 3);

    if(EncodedSample & 0x10)
        Difference += (StepSize >> 4);

    if(EncodedSample & 0x20)
        Difference += (StepSize >> 5);

    return UpdatePredictedSample(PredictedSample, EncodedSample, Difference);
}