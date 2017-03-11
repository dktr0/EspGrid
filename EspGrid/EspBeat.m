//
//  EspBeat.m
//
//  This file is part of EspGrid.  EspGrid is (c) 2012,2013 by David Ogborn.
//
//  EspGrid is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  EspGrid is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with EspGrid.  If not, see <http://www.gnu.org/licenses/>.

#import "EspBeat.h"
#import "EspGridDefs.h"

#ifndef GNUSTEP
#import <AudioToolBox/AudioToolbox.h>
#import <CoreAudio/HostTime.h>
#endif

@implementation EspBeat
{
#ifndef GNUSTEP
    AudioUnit audioUnit;
    mach_timebase_info_data_t tinfo;
    double factor;
    UInt64 systemMinusMach;
    bool isTicking;
#endif
}

@synthesize on;
@synthesize tempo;
@synthesize downbeatTime;
@synthesize downbeatNumber;

+(EspBeat*) beat
{
    static EspBeat* sharedObject = nil;
    if(!sharedObject)sharedObject = [[EspBeat alloc] init];
    return sharedObject;
}

-(id) init
{
    self = [super init];
    [self setOn:[NSNumber numberWithBool:NO]];
    [self setTempo:[NSNumber numberWithDouble:120.0]];
    [self setDownbeatTime:[NSNumber numberWithLongLong:0]];
    [self setDownbeatNumber:[NSNumber numberWithInt:0]];
    beatsIssued = 0;
    kvc = [EspKeyValueController keyValueController];
    [kvc addKeyPath:@"beat.params" type:ESP_KVCTYPE_BEAT];
    return self;
}

-(void) dealloc
{
    [self stopTicking];
    [super dealloc];
}


-(NSDictionary*) params
{
    return params;
}


-(void) setParams:(NSDictionary *)p
{
    if(params != NULL) [params release];
    params = [p copy];
    NSAssert(params != NULL,@"EspBeat params dictionary is null");
    [self setDownbeatNumber:[params objectForKey:@"downbeatNumber"]];
    [self setTempo:[params objectForKey:@"tempo"]];
    [self setDownbeatTime:[params objectForKey:@"downbeatTime"]];
    [self setOn:[params objectForKey:@"on"]];
}

-(void) atTime:(EspTimeType)t tempo:(double)bpm beatNumber:(long long)n on:(bool)o
{
    // this method creates a dictionary containing all tempo parameters and then
    // shares it to other EspGrid instances via the EspKeyValueController class
    NSDictionary* d = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithLongLong:t],@"downbeatTime",
                       [NSNumber numberWithDouble:bpm],@"tempo",
                       [NSNumber numberWithLong:n],@"downbeatNumber",
                       [NSNumber numberWithBool:o],@"on",nil];
    [kvc setValue:d forKeyPath:@"beat.params"];
}


-(void) turnBeatOn
{
    if([on boolValue]==YES) return;
    EspTimeType t = monotonicTime() + 100000000; // fixed 100ms latency compensation for now
    double f = [[self tempo] doubleValue];
    [self atTime:t tempo:f beatNumber:beatsIssued on:YES];
}

-(void) turnBeatOff
{
    if([on boolValue]==NO) return;
    EspTimeType elapsedTime = monotonicTime() - [self adjustedDownbeatTime];
    EspTimeType nanosPerBeat = 60000000000.0 / [tempo doubleValue];
    EspTimeType elapsedBeats = elapsedTime / nanosPerBeat;
    beatsIssued = elapsedBeats + [downbeatNumber longValue];
    EspTimeType t = monotonicTime() + 100000000; // fixed 100ms latency compensation for now
    double f = [[self tempo] doubleValue];
    [self atTime:t tempo:f beatNumber:beatsIssued on:NO];
}

-(void) changeTempo:(double)newBpm
{
    if([tempo doubleValue]==newBpm)return;
    if(newBpm<=0.0)newBpm=0.000000060;
    if(![on boolValue])
    {
        EspTimeType t = monotonicTime() + 100000000; // fixed 100ms latency compensation for now
        [self atTime:t tempo:newBpm beatNumber:beatsIssued on:NO];
    }
    else
    {
        EspTimeType downbeat = [self adjustedDownbeatTime];
        EspTimeType elapsedTime = monotonicTime() - downbeat;
        EspTimeType nanosPerBeat = 60000000000.0 / [tempo doubleValue];
        EspTimeType elapsedBeats = elapsedTime / nanosPerBeat;
        EspTimeType nextTime = downbeat + (elapsedBeats*nanosPerBeat) + nanosPerBeat;
        unsigned long nextBeat = [downbeatNumber unsignedLongValue] + elapsedBeats + 1;
        [self atTime:nextTime tempo:newBpm beatNumber:nextBeat on:YES];
    }
}


-(EspTimeType) adjustedDownbeatTime
{
    if([on boolValue]) return [downbeatTime longLongValue] + [kvc clockAdjustmentForAuthority:@"beat.params"];
    else return 0;
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    if([address isEqual:@"/esp/beat/on"]) 
    {
        if([d count]!=1){postProblem(@"received /esp/beat/on with wrong number of parameters",self); return NO;}
        int x = [[d objectAtIndex:0] intValue];
        if(x)[self turnBeatOn]; else [self turnBeatOff];
        return YES;
    }
    else if([address isEqual:@"/esp/beat/tempo"])
    {
        if([d count]!=1){postProblem(@"received /esp/beat/tempo with wrong number of parameters",self); return NO;}
        float x = [[d objectAtIndex:0] floatValue];
        [self changeTempo:x];
        return YES;
    }
    return NO;
}

-(bool) startTicking
{
#ifndef GNUSTEP
    if(isTicking)return YES;
    OSStatus err;
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_DefaultOutput;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent component = AudioComponentFindNext(NULL,&description);
    if(!component) { postProblem(@"unable to find default output!",nil); return NO; }
    err = AudioComponentInstanceNew(component, &audioUnit);
    if(err!=noErr) { postProblem(@"error creating instance of default output!",nil); return NO; }
    AURenderCallbackStruct rcbs;
    rcbs.inputProc = EspTickRenderProc;
    rcbs.inputProcRefCon = self;
    err = AudioUnitSetProperty(audioUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &rcbs,
                               sizeof(rcbs)
                               );
    if(err!=noErr) { postProblem(@"error setting render callback!",nil); return NO; }
    err = AudioUnitInitialize(audioUnit);
    if(err!=noErr) { postProblem(@"error initializing audio unit!",nil); return NO; }
    err = AudioOutputUnitStart(audioUnit);
    if(err!=noErr) { postProblem(@"error in AudioOutputUnitStart",nil); return NO; }
    isTicking = YES;
    return YES;
#else
    return NO;
#endif
}

-(void) stopTicking
{
#ifndef GNUSTEP
    if(!isTicking)return;
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    isTicking = NO;
#endif
}

#ifndef GNUSTEP
OSStatus EspTickRenderProc(void* inRefCon,
                           AudioUnitRenderActionFlags* ioActionFlags,
                           const AudioTimeStamp* inTimeStamp,
                           UInt32 inBusNumber,
                           UInt32 inNumberFrames,
                           AudioBufferList* ioData)
{
    // set output buffers to 0
    Float32* left = (Float32*)ioData->mBuffers[0].mData;
    Float32* right = (Float32*)ioData->mBuffers[1].mData;
    memset(left, 0, sizeof(Float32)*inNumberFrames);
    memset(right, 0, sizeof(Float32)*inNumberFrames);
    // if the beat is on, and a beat occurs in this frame, write it
    EspBeat* beat = (EspBeat*)inRefCon;
    if([[beat on] boolValue])
    {
        EspTimeType bufferTime = AudioConvertHostTimeToNanos(inTimeStamp->mHostTime);
        EspTimeType downbeat = [beat adjustedDownbeatTime];
        EspTimeType timeToNextBeat;
        if(downbeat>bufferTime) timeToNextBeat = downbeat - bufferTime;
        else
        {
            EspTimeType nanosPerBeat = ((EspTimeType)60000000000) / [[beat tempo] doubleValue];
            unsigned long nextBeat = ((bufferTime - downbeat) / nanosPerBeat) + 1;
            timeToNextBeat = downbeat + (nextBeat * nanosPerBeat) - bufferTime;
        }
        UInt64 index = timeToNextBeat * 441 / 10000000; // NOTE: fixed 44.1 kHZ sample rate
        if(index < inNumberFrames) { left[index]=0.966; right[index]=0.966; }
    }
    return noErr;
}
#endif

@end
