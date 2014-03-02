//
//  EspGrid.m
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

#import "EspGrid.h"
#import "EspGridDefs.h"

@implementation EspGrid
@synthesize versionString;
@synthesize title;
@synthesize internal;
@synthesize bridge;
@synthesize osc;
@synthesize peerList;
@synthesize clock;
@synthesize beat;
@synthesize chat;
@synthesize kvc;
@synthesize codeShare;
@synthesize message;
@synthesize queue;
@synthesize highVolumePosts;

EspGrid* currentGrid;
 
+(void) initialize
{
    NSMutableDictionary* defs = [NSMutableDictionary dictionary];
    [defs setObject:@"unknown" forKey:@"name"];
    [defs setObject:@"unknown" forKey:@"machine"];
    [defs setObject:@"255.255.255.255" forKey:@"broadcast"];
    [defs setObject:[NSNumber numberWithBool:YES] forKey:@"connectToMax"];
    [defs setObject:[NSNumber numberWithBool:YES] forKey:@"connectToChuck"];
    [defs setObject:[NSNumber numberWithBool:YES] forKey:@"connectToPD"];
    [defs setObject:[NSNumber numberWithBool:YES] forKey:@"connectToSupercollider"];
    [defs setObject:[NSNumber numberWithBool:NO] forKey:@"connectToCustom1"];
    [defs setObject:[NSNumber numberWithBool:NO] forKey:@"connectToCustom2"];
    [defs setObject:[NSNumber numberWithBool:NO] forKey:@"connectToCustom3"];
    [defs setObject:[NSNumber numberWithBool:NO] forKey:@"connectToCustom4"];
    [defs setObject:[NSNumber numberWithInt:2] forKey:@"clockMode"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}

-(void) logUserDefaults
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSLog(@" name=%@ machine=%@ broadcast=%@ clockMode=%@",
          [defs objectForKey:@"name"],
          [defs objectForKey:@"machine"],
          [defs objectForKey:@"broadcast"],
          [defs objectForKey:@"clockMode"]);
    if([[defs objectForKey:@"connectToMax"] boolValue]) NSLog(@" connecting/sending to Max on port 5511");
    if([[defs objectForKey:@"connectToChuck"] boolValue]) NSLog(@" connecting/sending to ChucK on port 5512");
    if([[defs objectForKey:@"connectToPD"] boolValue]) NSLog(@" connecting/sending to PD on port 5513");
    if([[defs objectForKey:@"connectToSupercollider"] boolValue]) NSLog(@" connecting/sending to SuperCollider on port 57120");
    // *** need to add custom connections here...
}

-(id) init
{
    currentGrid = self = [super init];
    highVolumePosts = NO;
    
    [self setVersionString:[NSString stringWithFormat:@"version %d.%2d.%d",
                            ESPGRID_MAJORVERSION,ESPGRID_MINORVERSION,ESPGRID_BUILDVERSION]];
    postLog(versionString,nil);
    [self setTitle:[NSString stringWithFormat:@"by David Ogborn"]];
    postLog(title,nil);
    
    [self logUserDefaults];

    peerList = [[EspPeerList alloc] init];

    internal = [[EspInternalProtocol alloc] init];
    [internal setPeerList:peerList];
    
    bridge = [[EspBridge alloc] init];
    [bridge setUdp:internal];
    [internal setBridge:bridge];
    
    osc = [[EspOsc alloc] init];
    
    clock = [[EspClock alloc] init];
    [clock setOsc:osc];
    [clock setUdp:internal];
    [clock setPeerList:peerList];
    
    kvc = [[EspKeyValueController alloc] init];
    [kvc setModel:self];
    [kvc setUdp:internal];
    [kvc setOsc:osc];
    [kvc setClock:clock];
    [kvc setPeerList:peerList];
    
    beat = [[EspBeat alloc] init];
    [beat setOsc:osc];
    [beat setUdp:internal];
    [beat setClock:clock];
    [beat setKvc:kvc];
    
    chat = [[EspChat alloc] init];
    [chat setOsc:osc];
    [chat setUdp:internal];
        
    codeShare = [[EspCodeShare alloc] init];
    [codeShare setOsc:osc];
    [codeShare setUdp:internal];
    [codeShare setClock:clock];
    
    queue = [[EspQueue alloc] init];
    [queue setClock:clock];
    
    message = [[EspMessage alloc] init];
    [message setClock:clock];
    [message setUdp:internal];
    [message setOsc:osc];
    [queue setDelegate:message];
    [message setQueue:queue];
    [message setPeerList:peerList];
    
    [kvc addKeyPath:@"beat.on"];
    [kvc addKeyPath:@"beat.tempo"];
    [kvc addKeyPath:@"beat.cycleLength"];
    [kvc addKeyPath:@"beat.downbeatTime"];
    [kvc addKeyPath:@"beat.downbeatNumber"];
    
    [internal setHandler:clock forOpcode:ESP_OPCODE_BEACON];
    [internal setHandler:clock forOpcode:ESP_OPCODE_ACK];
    [internal setHandler:chat forOpcode:ESP_OPCODE_CHATSEND];
    [internal setHandler:kvc forOpcode:ESP_OPCODE_KVC];
    [internal setHandler:codeShare forOpcode:ESP_OPCODE_ANNOUNCESHARE];
    [internal setHandler:codeShare forOpcode:ESP_OPCODE_REQUESTSHARE];
    [internal setHandler:codeShare forOpcode:ESP_OPCODE_DELIVERSHARE];
    [internal setHandler:message forOpcode:ESP_OPCODE_OSCNOW];
    [internal setHandler:message forOpcode:ESP_OPCODE_OSCFUTURE];
    
    [osc addHandler:beat forAddress:@"/esp/beat/on"];
    [osc addHandler:beat forAddress:@"/esp/beat/tempo"];
    [osc addHandler:beat forAddress:@"/esp/beat/cycleLength"];
    [osc addHandler:chat forAddress:@"/esp/chat/send"];
    [osc addHandler:codeShare forAddress:@"/esp/codeShare/post"];
    
    [osc addHandler:message forAddress:@"/esp/msg/now"];
    [osc addHandler:message forAddress:@"/esp/msg/soon"];
    [osc addHandler:message forAddress:@"/esp/msg/future"];
    [osc addHandler:message forAddress:@"/esp/msg/nowStamp"];
    [osc addHandler:message forAddress:@"/esp/msg/soonStamp"];
    [osc addHandler:message forAddress:@"/esp/msg/futureStamp"];
    
    [osc addHandler:bridge forAddress:@"/esp/bridge/localGroup"];
    [osc addHandler:bridge forAddress:@"/esp/bridge/localAddress"];
    [osc addHandler:bridge forAddress:@"/esp/bridge/localPort"];
    [osc addHandler:bridge forAddress:@"/esp/bridge/remoteAddress"];
    [osc addHandler:bridge forAddress:@"/esp/bridge/remotePort"];
    
    [osc addHandler:self forAddress:@"/esp/name"];
    [osc addHandler:self forAddress:@"/esp/machine"];
    [osc addHandler:self forAddress:@"/esp/broadcast"];
    [osc addHandler:self forAddress:@"/esp/clockMode"];
    [osc addHandler:self forAddress:@"/esp/connectToMax"];
    [osc addHandler:self forAddress:@"/esp/connectToChuck"];
    [osc addHandler:self forAddress:@"/esp/connectToPD"];
    [osc addHandler:self forAddress:@"/esp/connectToSupercollider"];
    [osc addHandler:self forAddress:@"/esp/customAddress1"];
    [osc addHandler:self forAddress:@"/esp/customPort1"];
    [osc addHandler:self forAddress:@"/esp/customAddress2"];
    [osc addHandler:self forAddress:@"/esp/customPort2"];
    [osc addHandler:self forAddress:@"/esp/customAddress3"];
    [osc addHandler:self forAddress:@"/esp/customPort3"];
    [osc addHandler:self forAddress:@"/esp/customAddress4"];
    [osc addHandler:self forAddress:@"/esp/customPort4"];
    
    [osc addHandler:self forAddress:@"/esp/syncMode"];
    
    // handlers for request-driven protocol
    [osc addHandler:self forAddress:@"/esp/tempo/q"]; // response will be /esp/tempo/r
    [osc addHandler:self forAddress:@"/esp/clock/q"]; // response will be /esp/clock/r
    
    return self;
}

-(void) dealloc
{
    [message release];
    [queue release];
    [codeShare release];
    [chat release];
    [beat release];
    [kvc release];
    [clock release];
    [osc release];
    [bridge release];
    [internal release];
    [peerList release];
    [super dealloc];
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
    [[NSUserDefaults standardUserDefaults] setObject:x forKey:key];
    return YES;
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    
    if([address isEqual:@"/esp/tempo/q"])
    {
        BOOL on = [[beat on] boolValue];
        float tempo = [[beat tempo] floatValue];
        EspTimeType time = [beat adjustedDownbeatTime];
        int seconds = (int)(time / 1000000000);
        int nanoseconds = (int)(time % 1000000000);
        long n = [[beat downbeatNumber] longValue];
        int length = [[beat cycleLength] intValue];
        NSArray* msg = [NSArray arrayWithObjects:@"/esp/tempo/r",
                        [NSNumber numberWithInt:on],
                        [NSNumber numberWithFloat:tempo],
                        [NSNumber numberWithInt:seconds],
                        [NSNumber numberWithInt:nanoseconds],
                        [NSNumber numberWithInt:(int)n],
                        [NSNumber numberWithInt:length],nil];
        if([d count] == 0) [osc transmit:msg toHost:h port:p log:NO]; // respond directly to host and port of incoming msg
        else if([d count] == 1) [osc transmit:msg toHost:h port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port, deduced host
        else if([d count] == 2) [osc transmit:msg toHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port+host
        else { postProblem(@"received /esp/tempo/q with too many parameters", self); }
        return YES;
    }
    
    if([address isEqual:@"/esp/clock/q"])
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
    
    if([address isEqual:@"/esp/name"]) return [self setDefault:@"name" withParameters:d];
    else if([address isEqual:@"/esp/machine"]) return [self setDefault:@"machine" withParameters:d];
    else if([address isEqual:@"/esp/broadcast"]) return [self setDefault:@"broadcast" withParameters:d];
    else if([address isEqual:@"/esp/clockMode"]) return [self setDefault:@"clockMode" withParameters:d];
    else if([address isEqual:@"/esp/connectToMax"]) return [self setDefault:@"connectToMax" withParameters:d];
    else if([address isEqual:@"/esp/connectToChuck"]) return [self setDefault:@"connectToChuck" withParameters:d];
    else if([address isEqual:@"/esp/connectToPD"]) return [self setDefault:@"connectToPD" withParameters:d];
    else if([address isEqual:@"/esp/connectToSupercollider"]) return [self setDefault:@"connectToSupercollider" withParameters:d];
    else if([address isEqual:@"/esp/customAddress1"]) return [self setDefault:@"custom1address" withParameters:d];
    else if([address isEqual:@"/esp/customPort1"]) return [self setDefault:@"custom1port" withParameters:d];
    else if([address isEqual:@"/esp/customAddress2"]) return [self setDefault:@"custom2address" withParameters:d];
    else if([address isEqual:@"/esp/customPort2"]) return [self setDefault:@"custom2port" withParameters:d];
    else if([address isEqual:@"/esp/customAddress3"]) return [self setDefault:@"custom3address" withParameters:d];
    else if([address isEqual:@"/esp/customPort3"]) return [self setDefault:@"custom3port" withParameters:d];
    else if([address isEqual:@"/esp/customAddress4"]) return [self setDefault:@"custom4address" withParameters:d];
    else if([address isEqual:@"/esp/customPort4"]) return [self setDefault:@"custom4port" withParameters:d];
    
    else if([address isEqual:@"/esp/syncMode"]) return [self setDefault:@"clockMode" withParameters:d];
    
    return NO;
}


-(void) postChat:(NSString*)m
{
    NSNotification* n = [NSNotification notificationWithName:@"chat" object:self userInfo:[NSDictionary dictionaryWithObject:m forKey:@"text"]];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:n waitUntilDone:NO];
}

-(void) postLog:(NSString*)m
{
    appendToLogFile(m);
    NSNotification* n = [NSNotification notificationWithName:@"log" object:self userInfo:[NSDictionary dictionaryWithObject:m forKey:@"text"]];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:n waitUntilDone:NO];
}

+(EspGrid*) currentGrid
{
    return currentGrid;
}

void appendToLogFile(NSString* s)
{
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
}

void postChat(NSString* s)
{
    NSLog(@"%@",s);
    [[EspGrid currentGrid] postChat:s];
}

void postWarning(NSString* s,id sender)
{
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [[EspGrid currentGrid] postChat:x];
    [[EspGrid currentGrid] postLog:x];
}

void postProblem(NSString* s,id sender)
{
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [[EspGrid currentGrid] postChat:x];
    [[EspGrid currentGrid] postLog:x];
}

void postLog(NSString* s,id sender)
{
    NSString* className = NSStringFromClass([sender class]);
    NSString* x;
    if(sender) x = [NSString stringWithFormat:@"%lld %@: %@",monotonicTime(),className,s];
    else x = [NSString stringWithFormat:@"%lld %@",monotonicTime(),s];
    NSLog(@"%@",x);
    [[EspGrid currentGrid] postLog:x];
}

void postLogHighVolume(NSString* s,id sender)
{
    if(![[EspGrid currentGrid] highVolumePosts])return;
    postLog(s,sender);
}

@end
