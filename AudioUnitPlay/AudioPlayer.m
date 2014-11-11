//
//  AudioPlayer.m
//  AudioUnitPlay
//
//  Created by liumiao on 11/11/14.
//  Copyright (c) 2014 Chang Ba. All rights reserved.
//

#import "AudioPlayer.h"
static OSStatus inputRenderCallback (
                                     
                                     void                        *inRefCon,      // A pointer to a struct containing the complete audio data
                                     //    to play, as well as state information such as the
                                     //    first sample to play on this invocation of the callback.
                                     AudioUnitRenderActionFlags  *ioActionFlags, // Unused here. When generating audio, use ioActionFlags to indicate silence
                                     //    between sounds; for silence, also memset the ioData buffers to 0.
                                     const AudioTimeStamp        *inTimeStamp,   // Unused here.
                                     UInt32                      inBusNumber,    // The mixer unit input bus that is requesting some new
                                     //        frames of audio data to play.
                                     UInt32                      inNumberFrames, // The number of frames of audio to provide to the buffer(s)
                                     //        pointed to by the ioData parameter.
                                     AudioBufferList             *ioData         // On output, the audio data to play. The callback's primary
//        responsibility is to fill the buffer(s) in the
//        AudioBufferList.
) {
    
    soundStruct    *soundStructPointer   = (soundStruct*) inRefCon;
    UInt32            frameTotalForSound        = soundStructPointer->frameCount;
    BOOL              isStereo                  = soundStructPointer->isStereo;
    
    // Declare variables to point to the audio buffers. Their data type must match the buffer data type.
    AudioUnitSampleType *dataInLeft;
    AudioUnitSampleType *dataInRight = NULL;
    
    dataInLeft                 = soundStructPointer->audioDataLeft;
    if (isStereo) dataInRight  = soundStructPointer->audioDataRight;
    
    // Establish pointers to the memory into which the audio from the buffers should go. This reflects
    //    the fact that each Multichannel Mixer unit input bus has two channels, as specified by this app's
    //    graphStreamFormat variable.
    AudioUnitSampleType *outSamplesChannelLeft;
    AudioUnitSampleType *outSamplesChannelRight;
    
    outSamplesChannelLeft                 = (AudioUnitSampleType *) ioData->mBuffers[0].mData;
    if (isStereo) outSamplesChannelRight  = (AudioUnitSampleType *) ioData->mBuffers[1].mData;
    
    // Get the sample number, as an index into the sound stored in memory,
    //    to start reading data from.
    UInt32 sampleNumber = soundStructPointer->sampleNumber;
    
    // Fill the buffer or buffers pointed at by *ioData with the requested number of samples
    //    of audio from the sound stored in memory.
    for (UInt32 frameNumber = 0; frameNumber < inNumberFrames; ++frameNumber) {
        
        outSamplesChannelLeft[frameNumber]                 = dataInLeft[sampleNumber];
        if (isStereo)
            outSamplesChannelRight[frameNumber]  = dataInRight[sampleNumber];
        
        sampleNumber++;
        
        // After reaching the end of the sound stored in memory--that is, after
        //    (frameTotalForSound / inNumberFrames) invocations of this callback--loop back to the
        //    start of the sound so playback resumes from there.
        if (sampleNumber >= frameTotalForSound) sampleNumber = 0;
    }
    
    // Update the stored sample number so, the next time this callback is invoked, playback resumes
    //    at the correct spot.
    soundStructPointer->sampleNumber = sampleNumber;
    
    return noErr;
}

@implementation AudioPlayer


- (id) init {
    
    self = [super init];
    
    if (!self) return nil;
    memset(&soundStructInfo, 0, sizeof(soundStructInfo));
    sampleRate = 44100.0;
    [self readAudioFilesIntoMemory];
    [self configureUnit];
    
    return self;
}
- (void) readAudioFilesIntoMemory {
    
    NSURL *guitarLoop = [[NSBundle mainBundle] URLForResource: @"500miles"
                                                         withExtension: @"mp3"];
        
    // Instantiate an extended audio file object.
    ExtAudioFileRef audioFileObject = 0;
    
    // Open an audio file and associate it with the extended audio file object.
    OSStatus result = ExtAudioFileOpenURL ((__bridge CFURLRef)guitarLoop, &audioFileObject);
    
    // Get the audio file's length in frames.
    UInt64 totalFramesInFile = 0;
    UInt32 frameLengthPropertySize = sizeof (totalFramesInFile);
    
    result =    ExtAudioFileGetProperty (
                                         audioFileObject,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &frameLengthPropertySize,
                                         &totalFramesInFile
                                         );
    
    // Assign the frame count to the soundStructArray instance variable
    soundStructInfo.frameCount = (UInt32)totalFramesInFile;
    
    // Get the audio file's number of channels.
    AudioStreamBasicDescription fileAudioFormat = {0};
    UInt32 formatPropertySize = sizeof (fileAudioFormat);
    
    result =    ExtAudioFileGetProperty (
                                         audioFileObject,
                                         kExtAudioFileProperty_FileDataFormat,
                                         &formatPropertySize,
                                         &fileAudioFormat
                                         );
    
    UInt32 channelCount = fileAudioFormat.mChannelsPerFrame;
    
    // Allocate memory in the soundStructArray instance variable to hold the left channel,
    //    or mono, audio data
    soundStructInfo.audioDataLeft =
    (AudioUnitSampleType *) calloc (totalFramesInFile, sizeof (AudioUnitSampleType));
    
    AudioStreamBasicDescription importFormat = {0};
    size_t bytesPerSample = sizeof (AudioUnitSampleType);
    
    // Fill the application audio format struct's fields to define a linear PCM,
    //        stereo, noninterleaved stream at the hardware sample rate.
    importFormat.mFormatID          = kAudioFormatLinearPCM;
    importFormat.mFormatFlags       = kAudioFormatFlagsAudioUnitCanonical;
    importFormat.mBytesPerPacket    = (UInt32)bytesPerSample;
    importFormat.mFramesPerPacket   = 1;
    importFormat.mBytesPerFrame     = (UInt32)bytesPerSample;
    importFormat.mBitsPerChannel    = 8 * (UInt32)bytesPerSample;
    importFormat.mSampleRate        = sampleRate;

    if (2 == channelCount) {
        
        soundStructInfo.isStereo = YES;
        // Sound is stereo, so allocate memory in the soundStructArray instance variable to
        //    hold the right channel audio data
        soundStructInfo.audioDataRight =
        (AudioUnitSampleType *) calloc (totalFramesInFile, sizeof (AudioUnitSampleType));
        importFormat.mChannelsPerFrame  = 2;
        
    } else if (1 == channelCount) {
        
        soundStructInfo.isStereo = NO;
        importFormat.mChannelsPerFrame  = 1;
        
    }
    fileASBD = importFormat;
        
    // Assign the appropriate mixer input bus stream data format to the extended audio
    //        file object. This is the format used for the audio data placed into the audio
    //        buffer in the SoundStruct data structure, which is in turn used in the
    //        inputRenderCallback callback function.
    
    result =    ExtAudioFileSetProperty (
                                         audioFileObject,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof (importFormat),
                                         &importFormat
                                         );

    
    // Set up an AudioBufferList struct, which has two roles:
    //
    //        1. It gives the ExtAudioFileRead function the configuration it
    //            needs to correctly provide the data to the buffer.
    //
    //        2. It points to the soundStructArray[audioFile].audioDataLeft buffer, so
    //            that audio data obtained from disk using the ExtAudioFileRead function
    //            goes to that buffer
    
    // Allocate memory for the buffer list struct according to the number of
    //    channels it represents.
    AudioBufferList *bufferList;
    
    bufferList = (AudioBufferList *) malloc (
                                             sizeof (AudioBufferList) + sizeof (AudioBuffer) * (channelCount - 1)
                                             );
    
    // initialize the mNumberBuffers member
    bufferList->mNumberBuffers = channelCount;
    
    // initialize the mBuffers member to 0
    AudioBuffer emptyBuffer = {0};
    size_t arrayIndex;
    for (arrayIndex = 0; arrayIndex < channelCount; arrayIndex++) {
        bufferList->mBuffers[arrayIndex] = emptyBuffer;
    }
    
    // set up the AudioBuffer structs in the buffer list
    bufferList->mBuffers[0].mNumberChannels  = 1;
    bufferList->mBuffers[0].mDataByteSize    = totalFramesInFile * sizeof (AudioUnitSampleType);
    bufferList->mBuffers[0].mData            = soundStructInfo.audioDataLeft;
    
    if (2 == channelCount) {
        bufferList->mBuffers[1].mNumberChannels  = 1;
        bufferList->mBuffers[1].mDataByteSize    = totalFramesInFile * sizeof (AudioUnitSampleType);
        bufferList->mBuffers[1].mData            = soundStructInfo.audioDataRight;
    }
    
    // Perform a synchronous, sequential read of the audio data out of the file and
    //    into the soundStructArray[audioFile].audioDataLeft and (if stereo) .audioDataRight members.
    UInt32 numberOfPacketsToRead = (UInt32) totalFramesInFile;
    
    result = ExtAudioFileRead (
                               audioFileObject,
                               &numberOfPacketsToRead,
                               bufferList
                               );
    
//    free (bufferList);
    
    if (noErr != result) {
        
        // If reading from the file failed, then free the memory for the sound buffer.
        free (soundStructInfo.audioDataLeft);
        soundStructInfo.audioDataLeft = 0;
        
        if (2 == channelCount) {
            free (soundStructInfo.audioDataRight);
            soundStructInfo.audioDataRight = 0;
        }
        
        ExtAudioFileDispose (audioFileObject);            
        return;
    }
    
    // Set the sample index to zero, so that playback starts at the 
    //    beginning of the sound.
    soundStructInfo.sampleNumber = 0;
    
    // Dispose of the extended audio file object, which also
    //    closes the associated file.
    ExtAudioFileDispose (audioFileObject);
}

- (void)configureUnit
{
    OSStatus status;
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    
    // Get audio units
    status = AudioComponentInstanceNew(inputComponent, &outputUnit);
    // Enable IO for recording
    UInt32 flag = 1;
    status = AudioUnitSetProperty(outputUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  0,
                                  &flag, 
                                  sizeof(flag));
    UInt32 busCount   = 1;
    status = AudioUnitSetProperty (
                                   outputUnit,
                                   kAudioUnitProperty_ElementCount,
                                   kAudioUnitScope_Input,
                                   0,
                                   &busCount,
                                   sizeof (busCount)
                                   );
    
    // Increase the maximum frames per slice allows the mixer unit to accommodate the
    //    larger slice size used when the screen is locked.
    UInt32 maximumFramesPerSlice = 4096;
    status = AudioUnitSetProperty (
                                   outputUnit,
                                   kAudioUnitProperty_MaximumFramesPerSlice,
                                   kAudioUnitScope_Global,
                                   0,
                                   &maximumFramesPerSlice,
                                   sizeof (maximumFramesPerSlice)
                                   );
    
    AURenderCallbackStruct callbackStruct;
    
    // Set output callback
    callbackStruct.inputProc = &inputRenderCallback;
    callbackStruct.inputProcRefCon = &soundStructInfo;
    status = AudioUnitSetProperty(outputUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  0,
                                  &callbackStruct, 
                                  sizeof(callbackStruct));
    
    // Fill the application audio format struct's fields to define a linear PCM,
    //        stereo, noninterleaved stream at the hardware sample rate.
    
    status = AudioUnitSetProperty (
                                   outputUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &fileASBD,
                                   sizeof (fileASBD)
                                   );
    status = AudioUnitSetProperty (
                                   outputUnit,
                                   kAudioUnitProperty_SampleRate,
                                   kAudioUnitScope_Input,
                                   0,
                                   &sampleRate,
                                   sizeof (sampleRate)
                                   );
    status = AudioUnitInitialize(outputUnit);

}
- (void)play
{
    OSStatus status = AudioOutputUnitStart(outputUnit);
}

- (void)stop
{
    OSStatus status = AudioOutputUnitStop(outputUnit);
}

- (void)dealloc
{
    if (soundStructInfo.audioDataLeft != NULL) {
        free (soundStructInfo.audioDataLeft);
        soundStructInfo.audioDataLeft = NULL;
    }
    if (soundStructInfo.audioDataRight != NULL) {
        free (soundStructInfo.audioDataRight);
        soundStructInfo.audioDataRight = NULL;
    }
    
}
@end
