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
@synthesize versionString;
@synthesize title;
@synthesize highVolumePosts;

+(void) initialize
{
    NSMutableDictionary* defs = [NSMutableDictionary dictionary];
    [defs setObject:@"unknown" forKey:@"person"];
    [defs setObject:@"unknown" forKey:@"machine"];
    [defs setObject:@"255.255.255.255" forKey:@"broadcast"];
    [defs setObject:[NSNumber numberWithInt:4] forKey:@"clockMode"]; // average reference beacon difference
    [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}


-(void) logUserDefaults
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSLog(@" person=%@ machine=%@ broadcast=%@ clockMode=%@",
          [defs objectForKey:@"person"],
          [defs objectForKey:@"machine"],
          [defs objectForKey:@"broadcast"],
          [defs objectForKey:@"clockMode"]);
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

-(id) init
{
    self = [super init];

    NSLog(@"sizeof EspOpcode = %d",sizeof(EspOpcode));
    NSLog(@"sizeof EspBeaconOpcode = %d",sizeof(EspBeaconOpcode));
    NSLog(@"sizeof EspAckOpcode = %d",sizeof(EspAckOpcode));
    NSLog(@"sizeof char = %d",sizeof(char));
    NSLog(@"sizeof int = %d",sizeof(int));
    NSLog(@"sizeof long = %d",sizeof(long));
    NSLog(@"sizeof EspTimeType = %d",sizeof(EspTimeType));

    #ifdef _WIN32
    QueryPerformanceFrequency(&performanceFrequency);
    #endif
    highVolumePosts = NO;
    versionString = [NSString stringWithFormat:@"version %d.%2d.%d",
                     ESPGRID_MAJORVERSION,ESPGRID_MINORVERSION,ESPGRID_SUBVERSION];
    postLog(versionString,nil);
    title = [NSString stringWithFormat:@"by David Ogborn"];
    postLog(title,nil);

    [self logUserDefaults];

    EspKeyValueController* kvc = [EspKeyValueController keyValueController];
    [kvc setModel:self];

    EspNetwork* network = [EspNetwork network];
    [network setHandler:[EspClock clock] forOpcode:ESP_OPCODE_BEACON];
    [network setHandler:[EspClock clock] forOpcode:ESP_OPCODE_ACK];
    [network setHandler:[EspChat chat] forOpcode:ESP_OPCODE_CHATSEND];
    [network setHandler:[EspKeyValueController keyValueController] forOpcode:ESP_OPCODE_KVC];
    [network setHandler:[EspCodeShare codeShare] forOpcode:ESP_OPCODE_ANNOUNCESHARE];
    [network setHandler:[EspCodeShare codeShare] forOpcode:ESP_OPCODE_REQUESTSHARE];
    [network setHandler:[EspCodeShare codeShare] forOpcode:ESP_OPCODE_DELIVERSHARE];
    [network setHandler:[EspMessage message] forOpcode:ESP_OPCODE_OSCNOW];
    [network setHandler:[EspMessage message] forOpcode:ESP_OPCODE_OSCFUTURE];

    EspOsc* osc = [EspOsc osc];

    [osc addHandler:osc forAddress:@"/esp/subscribe"];
    [osc addHandler:osc forAddress:@"/esp/unsubscribe"];

    [osc addHandler:self forAddress:@"/esp/person/s"]; // set name of person
    [osc addHandler:self forAddress:@"/esp/person/q"]; // query name, response: /esp/person/r
    [osc addHandler:self forAddress:@"/esp/machine/s"]; // etc...
    [osc addHandler:self forAddress:@"/esp/machine/q"];
    [osc addHandler:self forAddress:@"/esp/broadcast/s"];
    [osc addHandler:self forAddress:@"/esp/broadcast/q"];
    [osc addHandler:self forAddress:@"/esp/clockMode/s"];
    [osc addHandler:self forAddress:@"/esp/clockMode/q"];
    [osc addHandler:self forAddress:@"/esp/version/q"];

    [osc addHandler:self forAddress:@"/esp/clock/q"];
    [osc addHandler:self forAddress:@"/esp/tempo/q"];
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
    [defs addObserver:self forKeyPath:@"clockMode" options:NSKeyValueObservingOptionNew context:nil];
    [defs addObserver:self forKeyPath:@"broadcast" options:NSKeyValueObservingOptionNew context:nil];

	// Note: on GNUSTEP/WIN32 preferences at the command-line don't seem to persist
	// unless, as in the following, we set them to their current values
	[defs setValue:[defs valueForKey:@"person"] forKey:@"person"];
	[defs setValue:[defs valueForKey:@"machine"] forKey:@"machine"];
	[defs setValue:[defs valueForKey:@"broadcast"] forKey:@"broadcast"];
	[defs setValue:[defs valueForKey:@"clockMode"] forKey:@"clockMode"];
	[defs synchronize];

    return self;
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
        EspTimeType time = [beat adjustedDownbeatTime];
        EspTimeType monotonicToSystem = systemTime() - monotonicTime();
//        NSLog(@"beat time on HPC is %lld",time);
//      NSLog(@"system time is approx. %lld",systemTime());
//        NSLog(@"HPC time is approx %lld",monotonicTime());
//        NSLog(@"diff is %lld",monotonicToSystem);
        time += monotonicToSystem; // translate high performance time into epoch of normal system clock
//        NSLog(@"adjusted beat time is %lld",time);
        // later there should be a variant of /esp/tempo/q that requests high performance time
        int seconds = (int)(time / 1000000000);
        int nanoseconds = (int)(time % 1000000000);
        long n = [[beat downbeatNumber] longValue];
        NSArray* msg = [NSArray arrayWithObjects:@"/esp/tempo/r",
                        [NSNumber numberWithInt:on],
                        [NSNumber numberWithFloat:tempo],
                        [NSNumber numberWithInt:seconds],
                        [NSNumber numberWithInt:nanoseconds],
                        [NSNumber numberWithInt:(int)n],nil];
        if([d count] == 0) [osc transmit:msg toHost:h port:p log:NO]; // respond directly to host and port of incoming msg
        else if([d count] == 1) [osc transmit:msg toHost:h port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port, deduced host
        else if([d count] == 2) [osc transmit:msg toHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port+host
        else { postProblem(@"received /esp/tempo/q with too many parameters", self); }
        return YES;
    }

    else if([address isEqual:@"/esp/clock/q"])
    {
        EspTimeType time = monotonicTime();
        int seconds = (int)(time / 1000000000);
        int nanoseconds = (int)(time % 1000000000);
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

    else if([address isEqual:@"/esp/machine/s"])
        return [self setDefault:@"machine" withParameters:d];
    else if([address isEqual:@"/esp/machine/q"])
    {
        [osc response:@"/esp/machine/r"
                value:[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"]
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
    NSLog(@"%@",s);
    [EspGrid postChat:s];
}

void postWarning(NSString* s,id sender)
{
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [EspGrid postChat:x];
    [EspGrid postLog:x];
}

void postProblem(NSString* s,id sender)
{
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [EspGrid postChat:x];
    [EspGrid postLog:x];
}

void postLog(NSString* s,id sender)
{
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [EspGrid postLog:x];
}

void postLogHighVolume(NSString* s,id sender)
{
    if(![[EspGrid grid] highVolumePosts])return;
    postLog(s,sender);
}

@end
