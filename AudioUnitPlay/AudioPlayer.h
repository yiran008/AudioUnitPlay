//
//  AudioPlayer.h
//  AudioUnitPlay
//
//  Created by liumiao on 11/11/14.
//  Copyright (c) 2014 Chang Ba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    BOOL  isStereo;
    UInt32  frameCount;
    UInt32  sampleNumber;
    AudioUnitSampleType  *audioDataLeft;
    AudioUnitSampleType  *audioDataRight;
} soundStruct, *soundStructPtr;

@interface AudioPlayer : NSObject
{
    Float64  sampleRate;
    soundStruct  soundStructInfo;
    AudioUnit  outputUnit;
    AudioStreamBasicDescription fileASBD;
}

- (void)play;
- (void)stop;
- (void)pause;
@end
