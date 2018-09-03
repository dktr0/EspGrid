//
//  EspGrid.m
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2015 by David Ogborn.
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

#import "EspGrid.h"
#import "EspGridDefs.h"

#ifdef _WIN32
LARGE_INTEGER performanceFrequency;
#endif

@implementation EspGrid

+(void) initialize
{
    NSMutableDictionary* defs = [NSMutableDictionary dictionary];
    time_t t;
    srand((unsigned)time(&t));
    NSString* random = [NSString stringWithFormat:@"?%u",rand(),nil];
    [defs setObject:random forKey:@"person"];
    [defs setObject:@"255.255.255.255" forKey:@"broadcast"];
    [defs setObject:[NSNumber numberWithInt:4] forKey:@"clockMode"]; // average reference beacon difference
    [defs setObject:[NSNumber numberWithInt:1] forKey:@"verbosity"]; // critical and "events" only - no protocol msgs
    [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}


-(void) logUserDefaults
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSString*m = [NSString stringWithFormat:@" person=%@ broadcast=%@ clockMode=%@ verbosity=%@",
          [defs objectForKey:@"person"],
          [defs objectForKey:@"broadcast"],
          [defs objectForKey:@"clockMode"],
                  [defs objectForKey:@"verbosity"]];
    logVerbosity = [[defs objectForKey:@"verbosity"] intValue];
    postCritical(m,nil);
}

+(EspGrid*) grid
{
    static EspGrid* sharedGrid = nil;
    if(!sharedGrid) sharedGrid = [[EspGrid alloc] init];
    {
        sharedGrid = [EspGrid alloc];
        [sharedGrid init];
    }
    return sharedGrid;
}

-(void) protocolTests
{
    int e = 0;
    e+=[self sizeOrOffset:sizeof(EspTimeType) shouldBe:8 name:@"sizeof(EspTimeType)"];
    e+=[self sizeOrOffset:sizeof(EspOpcode) shouldBe:56 name:@"sizeof(EspOpcode)"];
    e+=[self sizeOrOffset:sizeof(EspBeaconOpcode) shouldBe:64 name:@"sizeof(EspBeaconOpcode)"];
    e+=[self sizeOrOffset:sizeof(EspAckOpcode) shouldBe:112 name:@"sizeof(EspAckOpcode)"];
    e+=[self sizeOrOffset:sizeof(EspPeerInfoOpcode) shouldBe:128 name:@"sizeof(EspPeerInfoOpcode)"];
    EspAckOpcode acktest;
    e+=[self sizeOrOffset:((void*)&acktest.beaconSend-(void*)&acktest) shouldBe:88 name:@"offset of EspAckOpcode.beaconSend"];
    e+=[self sizeOrOffset:((void*)&acktest.beaconReceive-(void*)&acktest) shouldBe:96 name:@"offset of EspAckOpcode.beaconSend"];
    if(e != 0)
    {
        NSLog(@"Because there are one or more protocol warnings above, this build of espgridd may fail to communicate with other instances of espgridd. This is either a bug in the software or a problem with the build environment.");
    }
}

-(int) sizeOrOffset:(size_t)s shouldBe:(size_t)t name:(NSString*)name
{
    if(s != t) {
        NSLog(@"***WARNING*** %@ should be %lu but is %lu",name,t,s);
        return 1;
    } else return 0;
}

-(id) init
{
    self = [super init];
    [self protocolTests];
    logVerbosity = 1;
    #ifdef _WIN32
    QueryPerformanceFrequency(&performanceFrequency);
    #endif
    NSString* versionString = [NSString stringWithFormat:@"version %d.%2d.%d",
                     ESPGRID_MAJORVERSION,ESPGRID_MINORVERSION,ESPGRID_SUBVERSION];
    postCritical(versionString,nil);

    [self logUserDefaults];

    EspKeyValueController* kvc = [EspKeyValueController keyValueController];
    [kvc setModel:self];
    
    EspNetwork* network = [EspNetwork network];
    [network setHandler:[EspClock clock] forOpcode:ESP_OPCODE_BEACON];
    [network setHandler:[EspClock clock] forOpcode:ESP_OPCODE_ACK];
    [network setHandler:[EspClock clock] forOpcode:ESP_OPCODE_PEERINFO];
    [network setHandler:[EspChat chat] forOpcode:ESP_OPCODE_CHATSEND];
    [network setHandler:[EspKeyValueController keyValueController] forOpcode:ESP_OPCODE_INT];
    [network setHandler:[EspKeyValueController keyValueController] forOpcode:ESP_OPCODE_FLOAT];
    [network setHandler:[EspKeyValueController keyValueController] forOpcode:ESP_OPCODE_TIME];
    [network setHandler:[EspKeyValueController keyValueController] forOpcode:ESP_OPCODE_STRING];
    [network setHandler:[EspKeyValueController keyValueController] forOpcode:ESP_OPCODE_METRE];
    [network setHandler:[EspMessage message] forOpcode:ESP_OPCODE_OSCNOW];
    [network setHandler:[EspMessage message] forOpcode:ESP_OPCODE_OSCFUTURE];

    EspOsc* osc = [EspOsc osc];

    [osc addHandler:osc forAddress:@"/esp/subscribe"];
    [osc addHandler:osc forAddress:@"/esp/unsubscribe"];

    [osc addHandler:self forAddress:@"/esp/person/s"]; // set name of person
    [osc addHandler:self forAddress:@"/esp/person/q"]; // query name, response: /esp/person/r
    [osc addHandler:self forAddress:@"/esp/broadcast/s"];
    [osc addHandler:self forAddress:@"/esp/broadcast/q"];
    [osc addHandler:self forAddress:@"/esp/clockMode/s"];
    [osc addHandler:self forAddress:@"/esp/clockMode/q"];
    [osc addHandler:self forAddress:@"/esp/version/q"];

    [osc addHandler:self forAddress:@"/esp/clock/q"];
    [osc addHandler:self forAddress:@"/esp/tempo/q"];
    [osc addHandler:self forAddress:@"/esp/tempoCPU/q"];
    [osc addHandler:[EspBeat beat] forAddress:@"/esp/beat/on"];
    [osc addHandler:[EspBeat beat] forAddress:@"/esp/beat/tempo"];
    [osc addHandler:[EspChat chat] forAddress:@"/esp/chat/send"];

    [osc addHandler:[EspCodeShare codeShare] forAddress:@"/esp/codeShare/post"];

    [osc addHandler:[EspMessage message] forAddress:@"/esp/msg/now"];
    [osc addHandler:[EspMessage message] forAddress:@"/esp/msg/soon"];
    [osc addHandler:[EspMessage message] forAddress:@"/esp/msg/future"];
    [osc addHandler:[EspMessage message] forAddress:@"/esp/msg/nowStamp"];
    [osc addHandler:[EspMessage message] forAddress:@"/esp/msg/soonStamp"];
    [osc addHandler:[EspMessage message] forAddress:@"/esp/msg/futureStamp"];

    [osc addHandler:self forAddress:@"/esp/bridge/localGroup"];
    [osc addHandler:self forAddress:@"/esp/bridge/localAddress"];
    [osc addHandler:self forAddress:@"/esp/bridge/localPort"];
    [osc addHandler:self forAddress:@"/esp/bridge/remoteAddress"];
    [osc addHandler:self forAddress:@"/esp/bridge/remotePort"];

    NSUserDefaults* defs= [NSUserDefaults standardUserDefaults];
    [[self clock] changeSyncMode:[[defs valueForKey:@"clockMode"] intValue]];
    [defs addObserver:self forKeyPath:@"person" options:NSKeyValueObservingOptionNew context:nil];
    [defs addObserver:self forKeyPath:@"clockMode" options:NSKeyValueObservingOptionNew context:nil];
    [defs addObserver:self forKeyPath:@"broadcast" options:NSKeyValueObservingOptionNew context:nil];

    // Note: on GNUSTEP/WIN32 preferences at the command-line don't seem to persist
    // unless, as in the following, we set them to their current values
    [defs setValue:[defs valueForKey:@"person"] forKey:@"person"];
    [defs setValue:[defs valueForKey:@"broadcast"] forKey:@"broadcast"];
    [defs setValue:[defs valueForKey:@"clockMode"] forKey:@"clockMode"];
    [defs synchronize];

    return self;
}

-(void) personChanged
{
    [[EspNetwork network] nameChanged];
    [[EspClock clock] personChanged];
    [[EspPeerList peerList] personChanged];
}


-(EspBeat*) beat
{
    return [EspBeat beat];
}

-(EspCodeShare*) codeShare
{
    return [EspCodeShare codeShare];
}

-(EspPeerList*) peerList
{
    return [EspPeerList peerList];
}

-(EspChannel*) bridge
{
    return [[EspNetwork network] bridge];
}

-(EspClock*) clock
{
    return [EspClock clock];
}

-(EspChat*) chat
{
    return [EspChat chat];
}

-(BOOL) setDefault:(NSString*)key withParameters:(NSArray*)d
{
    if([d count]!=1)
    {
        NSString* l = [NSString stringWithFormat:@"received OSC to change %@ with wrong number of parameters",key];
        postProblem(l, self);
        return NO;
    }
    id x = [d objectAtIndex:0];
    NSString* log = [NSString stringWithFormat:@"default %@ changed to %@",key,x];
    postLog(log, self);
	NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
	#ifdef GNUSTEP
	[defs willChangeValueForKey:key];
    #endif
	[defs setObject:x forKey:key];
	#ifdef GNUSTEP
	[defs didChangeValueForKey:key];
	#endif
	[defs synchronize];
    return YES;
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    EspOsc* osc = [EspOsc osc];
    if([address isEqual:@"/esp/tempo/q"])
    {
        EspBeat* beat = [EspBeat beat];
        BOOL on = [[beat on] boolValue];
        float tempo = [[beat tempo] floatValue];
        EspTimeType beatTime = [beat adjustedDownbeatTime];
        EspTimeType sTime = systemTime();
        EspTimeType mTime = monotonicTime();
        EspTimeType monotonicToSystem = sTime - mTime;
        EspTimeType time = beatTime + monotonicToSystem; // translate high performance time into epoch of normal system clock
        int seconds = (int)(time / (EspTimeType)1000000000);
        int nanoseconds = (int)(time % (EspTimeType)1000000000);
        // NSLog(@"beatTime=%lld   sTime=%lld   mTime=%lld   monotonicToSystem=%lld   time=%lld",beatTime,sTime,mTime,monotonicToSystem,time);
        long n = [[beat beat] longValue];
        // NSLog(@"about to /esp/tempo/r %d %f %d %d %d",on,tempo,seconds,nanoseconds,(int)n);
        NSArray* msg = [NSArray arrayWithObjects:@"/esp/tempo/r",
                        [NSNumber numberWithInt:on],
                        [NSNumber numberWithFloat:tempo],
                        [NSNumber numberWithInt:seconds],
                        [NSNumber numberWithInt:nanoseconds],
                        [NSNumber numberWithInt:(int)n],nil];
        // NSLog(@"%@",msg);
        if([d count] == 0) [osc transmit:msg toHost:h port:p log:NO]; // respond directly to host and port of incoming msg
        else if([d count] == 1) [osc transmit:msg toHost:h port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port, deduced host
        else if([d count] == 2) [osc transmit:msg toHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port+host
        else { postProblem(@"received /esp/tempo/q with too many parameters", self); }
        return YES;
    }

    else if([address isEqual:@"/esp/tempoCPU/q"])
    {
        EspBeat* beat = [EspBeat beat];
        BOOL on = [[beat on] boolValue];
        float tempo = [[beat tempo] floatValue];
        EspTimeType time = [beat adjustedDownbeatTime];
        int seconds = (int)(time / (EspTimeType)1000000000);
        int nanoseconds = (int)(time % (EspTimeType)1000000000);
        long n = [[beat beat] longValue];
        NSArray* msg = [NSArray arrayWithObjects:@"/esp/tempoCPU/r",
                        [NSNumber numberWithInt:on],
                        [NSNumber numberWithFloat:tempo],
                        [NSNumber numberWithInt:seconds],
                        [NSNumber numberWithInt:nanoseconds],
                        [NSNumber numberWithInt:(int)n],nil];
        if([d count] == 0) [osc transmit:msg toHost:h port:p log:NO]; // respond directly to host and port of incoming msg
        else if([d count] == 1) [osc transmit:msg toHost:h port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port, deduced host
        else if([d count] == 2) [osc transmit:msg toHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port+host
        else { postProblem(@"received /esp/tempoCPU/q with too many parameters", self); }
        return YES;
    }

    else if([address isEqual:@"/esp/clock/q"])
    {
        EspTimeType time = monotonicTime();
        int seconds = (int)(time / (EspTimeType)1000000000);
        int nanoseconds = (int)(time % (EspTimeType)1000000000);
        NSArray* msg = [NSArray arrayWithObjects:@"/esp/clock/r",
                        [NSNumber numberWithInt:seconds],[NSNumber numberWithInt:nanoseconds],nil];
        if([d count] == 0) [osc transmit:msg toHost:h port:p log:NO]; // respond directly to host and port of incoming msg
        else if([d count] == 1) [osc transmit:msg toHost:h port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port, deduced host
        else if([d count] == 2) [osc transmit:msg toHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port+host
        else { postProblem(@"received /esp/clock/q with too many parameters", self); }
        return YES;
    }

    else if([address isEqual:@"/esp/person/s"])
        return [self setDefault:@"person" withParameters:d];
    else if([address isEqual:@"/esp/person/q"])
    {
        [osc response:@"/esp/person/r"
                value:[[NSUserDefaults standardUserDefaults] stringForKey:@"person"]
              toQuery:d
             fromHost:h
                 port:p];
    }

    else if([address isEqual:@"/esp/broadcast/s"])
        return [self setDefault:@"broadcast" withParameters:d];
    else if([address isEqual:@"/esp/broadcast/q"])
    {
        [osc response:@"/esp/broadcast/r"
                value:[[NSUserDefaults standardUserDefaults] stringForKey:@"broadcast"]
              toQuery:d
             fromHost:h
                 port:p];
    }

    else if([address isEqual:@"/esp/clockMode/s"])
        return [self setDefault:@"clockMode" withParameters:d];
    else if([address isEqual:@"/esp/clockMode/q"])
    {
        [osc response:@"/esp/clockMode/r"
                value:[[NSUserDefaults standardUserDefaults] objectForKey:@"clockMode"]
              toQuery:d
             fromHost:h
                 port:p];
    }

    else if([address isEqual:@"/esp/version/q"])
    {
        NSString* version = [NSString stringWithFormat:@"%d.%d.%d",
                             ESPGRID_MAJORVERSION,ESPGRID_MINORVERSION,ESPGRID_SUBVERSION,nil];
        [osc response:@"/esp/version/r"
                value:version
              toQuery:d
             fromHost:h
                 port:p];
    }

    else if([address isEqual:@"/esp/bridge/port"])
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/port with wrong number of parameters", self);
            return NO;
        }
        [[[EspNetwork network] bridge] setPort:[[d objectAtIndex:0] intValue]];
        return YES;
    }
    else if([address isEqual:@"/esp/bridge/host"])
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/host with wrong number of parameters", self);
            return NO;
        }
        [[[EspNetwork network] bridge] setHost:[d objectAtIndex:0]];
        return YES;
    }
    return NO;
}


-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"broadcast"]) [[EspNetwork network] broadcastAddressChanged];
    else if([keyPath isEqualToString:@"person"]) [self personChanged];
    else if([keyPath isEqualToString:@"clockMode"]) [[self clock] changeSyncMode:[[[NSUserDefaults standardUserDefaults] valueForKey:@"clockMode"] intValue]];
    else NSLog(@"PROBLEM: received KVO notification for unexpected keyPath %@",keyPath);
}


+(void) postChat:(NSString*)m
{
    NSNotification* n = [NSNotification notificationWithName:@"chat" object:nil userInfo:[NSDictionary dictionaryWithObject:m forKey:@"text"]];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:n waitUntilDone:NO];
}

+(void) postLog:(NSString*)m
{
    appendToLogFile(m);
    NSNotification* n = [NSNotification notificationWithName:@"log" object:nil userInfo:[NSDictionary dictionaryWithObject:m forKey:@"text"]];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:n waitUntilDone:NO];
}

void appendToLogFile(NSString* s)
{
#ifndef _WIN32
	// this doesn't work on Windows for the time being...
    NSString* directory = [(NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)) objectAtIndex:0];
    NSString* path = [directory stringByAppendingPathComponent:@"espgridLog.txt"];
    NSString* s2 = [NSString stringWithFormat:@"%@\n",s];
    if(![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        [s2 writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    else
    {
        NSFileHandle* handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
        [handle seekToEndOfFile];
        [handle writeData:[s2 dataUsingEncoding:NSUTF8StringEncoding]];
    }
#endif
}

void postChat(NSString* s)
{
    postEvent(s,nil);
    [EspGrid postChat:s];
}

void postWarning(NSString* s,id sender) // DEPRECATED
{
    postCritical(s,sender);
}

void postProblem(NSString* s,id sender) // DEPRECATED
{
    postCritical(s,sender);
}

void postLog(NSString* s,id sender) // DEPRECATED - some calls should be postEvent, others postProtocolLow, etc
{
    postEvent(s,sender);
}

void postLogHighVolume(NSString* s,id sender) // DEPRECATED
{
    postProtocolHigh(s,sender);
}

// Verbosity levels
// 0 = only start-up, critical exceptions, chat messages - postCritical
// 1 = (default) only "interesting events" - postEvent
// 2 = "v" low volume external and internal protocol events - postProtocolLow
// 3 = "vv" all external and internal protocol events - postProtocolHigh

void postCritical(NSString* s, id sender)
{
    postLogWithLevel(s,sender,0);
}

void postEvent(NSString* s, id sender)
{
    postLogWithLevel(s,sender,1);
}

void postProtocolLow(NSString* s, id sender)
{
    postLogWithLevel(s,sender,2);
}

void postProtocolHigh(NSString* s, id sender)
{
    postLogWithLevel(s,sender,3);
}

static int logVerbosity = 1;

void postLogWithLevel(NSString* s, id sender, int level)
{
    if(logVerbosity < level) return;
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld: %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [EspGrid postLog:x];
    if(level == 0) [EspGrid postChat:x]; // so that critical problems go to chat window in GUI
}

@end
