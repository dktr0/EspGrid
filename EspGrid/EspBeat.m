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
@synthesize cycleLength;

+(EspBeat*) beat
{
    static EspBeat* sharedObject = nil;
    if(!sharedObject)sharedObject = [[EspBeat alloc] init];
    return sharedObject;
}

-(id) init
{
    self = [super init];
    osc = [EspOsc osc];
    network = [EspNetwork network];
    clock = [EspClock clock];
    kvc = [EspKeyValueController keyValueController];
    [self setOn:[NSNumber numberWithBool:NO]];
    [self setTempo:[NSNumber numberWithDouble:120.0]];
    [self setCycleLength:[NSNumber numberWithInt:4]];
    [self setDownbeatTime:[NSNumber numberWithLongLong:0]];
    [self setDownbeatNumber:[NSNumber numberWithInt:0]];
    beatsIssued = 0;
    return self;
}

-(void) dealloc
{
    [self stopTicking];
    [super dealloc];
}


-(void) turnBeatOn
{
    if([on boolValue]==YES) return;
    postLog(@"turning beat on", self);
    EspTimeType stamp = monotonicTime() + 100000000; // fixed 100ms latency compensation for now
    [kvc setValue:[NSNumber numberWithDouble:stamp] forKeyPath:@"beat.downbeatTime"];
    [kvc setValue:[NSNumber numberWithBool:YES] forKeyPath:@"beat.on"];
    [kvc setValue:[NSNumber numberWithLong:beatsIssued] forKeyPath:@"beat.downbeatNumber"];
}

-(void) turnBeatOff
{
    if([on boolValue]==NO) return;
    postLog(@"turning beat off",self);
    // double beats = ([clock currentAdjustedTime] - [downbeatTime doubleValue])*[tempo doubleValue]/60.0;
    EspTimeType elapsedTime = monotonicTime() - [self adjustedDownbeatTime];
    EspTimeType nanosPerBeat = 60000000000.0 / [tempo doubleValue];
    EspTimeType elapsedBeats = elapsedTime / nanosPerBeat;
    beatsIssued = elapsedBeats + [downbeatNumber longValue];
    [kvc setValue:[NSNumber numberWithBool:NO] forKeyPath:@"beat.on"];
}

-(void) changeTempo:(double)newBpm
{
    if([tempo doubleValue]==newBpm)return;
    if(newBpm<=0.0)newBpm=0.000000060;
    postLog([NSString stringWithFormat:@"changing tempo to %lf",newBpm],self);
    if(![on boolValue])
    {
        [kvc setValue:[NSNumber numberWithDouble:newBpm] forKeyPath:@"beat.tempo"];
    }
    else
    {
        EspTimeType downbeat = [self adjustedDownbeatTime];
        EspTimeType elapsedTime = monotonicTime() - downbeat;
        EspTimeType nanosPerBeat = 60000000000.0 / [tempo doubleValue];
        EspTimeType elapsedBeats = elapsedTime / nanosPerBeat;
        EspTimeType nextTime = downbeat + (elapsedBeats*nanosPerBeat) + nanosPerBeat;
        unsigned long nextBeat = [downbeatNumber unsignedLongValue] + elapsedBeats + 1;
        NSLog(@"downbeat=%lld elapsed=%lld nanosperbeat=%lld beats=%lld nextTime=%lld nextBeat=%lu",
              downbeat,elapsedTime,nanosPerBeat,elapsedBeats,nextTime,nextBeat);
        [kvc setValue:[NSNumber numberWithDouble:newBpm] forKeyPath:@"beat.tempo"];
        [kvc setValue:[NSNumber numberWithLongLong:nextTime] forKeyPath:@"beat.downbeatTime"];
        [kvc setValue:[NSNumber numberWithUnsignedLong:nextBeat] forKeyPath:@"beat.downbeatNumber"];
    }
}
    
// this needs to be reconsidered in light of recent changes to other things
-(void) changeCycleLength:(int)newLength
{
    if(newLength == [cycleLength intValue])return;
    postLog(@"changing cycle length",self);
    [kvc setValue:[NSNumber numberWithInt:newLength] forKeyPath:@"beat.cycleLength"];
}

-(EspTimeType) adjustedDownbeatTime
{
    if([on boolValue]) return [downbeatTime longLongValue] + [kvc clockAdjustmentForAuthority:@"beat.downbeatTime"];
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
    else if([address isEqual:@"/esp/beat/cycleLength"])
    {
        if([d count]!=1){postProblem(@"received /esp/beat/cycleLength with wrong number of parameters",self); return NO;}
        int x = [[d objectAtIndex:0] intValue];
        if(x<=0)x=1;
        [self changeCycleLength:x];
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
