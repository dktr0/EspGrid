//
//  EspBridge.m
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

#import "EspBridge.h"
#import "EspGridDefs.h"
#import "EspSocket.h"

@implementation EspBridge
@synthesize localGroup;
@synthesize localAddress;
@synthesize remoteAddress;
@synthesize remotePort;
@synthesize remoteGroup;
@synthesize remoteClaimedAddress;
@synthesize remoteClaimedPort;
@synthesize remotePackets;
@synthesize udp;


-(id) init
{
    self = [super init];
    [self changeLocalPort:5508];
    [self setRemotePort:@"0"];
    return self;
}

-(void) dealloc
{
    [udpReceive release];
    [super dealloc];
}

-(void) changeLocalPort:(int)p
{
    localPort = p;
    udpReceive = [[EspSocket alloc] initWithPort:p andDelegate:self];
}

-(void) temporaryLog:(NSString*)msg
{
    NSString* s = [NSString stringWithFormat:@"%@ (local=:%d remote=%@:%@)",msg,localPort,remoteAddress,remotePort];
    postLog(s,self);
}

-(void) transmitOpcode:(NSDictionary*)d
{   // called (by EspInternalProtocol) when this instance issues an opcode, in order to transmit it over the bridge
    if(![self active]) return; // does nothing if bridge inactive
    [self temporaryLog:@"transmitOpcode"];
    // append local group name and self address as group address
    NSMutableDictionary* n = [NSMutableDictionary dictionaryWithDictionary:d];
    [n setObject:[localGroup copy] forKey:@"localGroup"];
    if(localAddress) [n setObject:[localAddress copy] forKey:@"localOriginAddress"];
    if(localAddress) [n setObject:[localAddress copy] forKey:@"localAddress"];
    if(localPort) [n setObject:[NSNumber numberWithInt:localPort] forKey:@"localPort"];
    else [n setObject:@"unknown" forKey:@"localOriginAddress"];
    NSError* err = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:n
                    format:NSPropertyListBinaryFormat_v1_0 options:0
                    error:&err];
    if(err != nil) postProblem(@"unable to serialize property list (opcode) as NSData", self);
    else [udpReceive sendData:data toHost:remoteAddress port:[remotePort intValue]];
}

-(void) retransmitOpcode:(NSDictionary*)d
{   // called (by EspInternalProtocol) when an opcode is received from a local peer and needs to be transmitted over the bridge
    if(![self active]) return; // does nothing if bridge inactive
    [self temporaryLog:@"retransmitOpcode"];

    // append local group name and self address as group address
    NSMutableDictionary* n = [NSMutableDictionary dictionaryWithDictionary:d];
    [n setObject:[localGroup copy] forKey:@"localGroup"];
    if(localAddress) [n setObject:[localAddress copy] forKey:@"localAddress"];
    [n setObject:[[d objectForKey:@"ip"] copy] forKey:@"localOriginAddress"];
    if(localPort) [n setObject:[NSNumber numberWithInt:localPort] forKey:@"localPort"];

    NSError* err = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:n
                                                              format:NSPropertyListBinaryFormat_v1_0 options:0
                                                               error:&err];
    if(err != nil) postProblem(@"unable to serialize property list (opcode) as NSData", self);
    else [udpReceive sendData:data toHost:remoteAddress port:[remotePort intValue]];
}

-(void) rebroadcastOpcode:(NSDictionary*)d
{   // called by [EspBridge dataReceived...] when an opcode is received from remote peer and needs to be broadcast to local peers
    if(![self active]) return; // does nothing if bridge inactive
    [self temporaryLog:@"rebroadcastOpcode"];
        
    NSError* err = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:d
                                                              format:NSPropertyListBinaryFormat_v1_0 options:0
                                                               error:&err];
    if(err != nil) {
        postProblem(@"unable to serialize property list (opcode) as NSData", self);
    } else {
        [udpReceive sendData:data
            toHost:[[NSUserDefaults standardUserDefaults] stringForKey:@"broadcast"]
            port:5509];
    }
}

-(BOOL) active
{
    // transmitting functions should only transmit if local group, address and port, and remote address and port are all complete
    if(localGroup == nil) return NO;
    if([localGroup length] < 1 ) return NO;
    if(localAddress == nil) return NO;
    if([localAddress length] < 1 ) return NO;
    if(localPort < 1) return NO;
    if(remoteAddress == nil) return NO;
    if([remoteAddress length] < 1) return NO;
    if([remotePort intValue] < 1) return NO;
    return YES;
}

- (void)dataReceived:(NSData*)d fromHost:(NSString*)h fromPort:(int)port systemTime:(EspTimeType)timestamp monotonicTime:(EspTimeType)monotonic
{
    
    NSAssert(d != nil, @"data should not be nil");
    NSAssert(h != nil, @"host should not be nil");
    NSError* err = nil;
    NSMutableDictionary* plist =
    (NSMutableDictionary*)[NSPropertyListSerialization propertyListWithData:d
                                                                    options:NSPropertyListMutableContainers format:NULL error:&err];
    
    NSString* s = [NSString stringWithFormat:@"dataReceived name=%@ machine=%@",[plist objectForKey:@"name"],[plist objectForKey:@"machine"]];
    [self temporaryLog:s];

    if(plist != nil)
    {
        // ignore this data if it is missing local group, address or port
        if([plist objectForKey:@"name"] == nil) { postProblem(@"received on bridge port with no name field",self); return; }
        if([plist objectForKey:@"machine"] == nil) { postProblem(@"received on bridge port with no machine field", self); return;}
        if([plist objectForKey:@"localGroup"] == nil) { postProblem(@"received on bridge port with no localGroup field", self); return; }
        if([plist objectForKey:@"localAddress"] == nil) { postProblem(@"received on bridge port with no localAddress field", self); return; }
        if([plist objectForKey:@"localPort"] == nil) { postProblem(@"received on bridge port with no localPort field", self); return; }
        
        // harvest remote group name, address and port, timestamp and packets received count
        [self setRemoteGroup:[plist objectForKey:@"localGroup"]];
        [self setRemoteClaimedAddress:[plist objectForKey:@"localAddress"]];
        [self setRemoteClaimedPort:[plist objectForKey:@"localPort"]];
        [plist setValue:[NSNumber numberWithDouble:timestamp] forKey:@"timeReceived"];
        [plist setValue:h forKey:@"ip"];
        remotePacketsLong++;
        [self setRemotePackets:[NSString stringWithFormat:@"%ld",remotePacketsLong]];
        
        // process opcode locally and rebroadcast for all local peers
        [udp handleOpcode:plist];
        
        // *** PROBLEM: rebroadcast is processed again by system (i.e. by non bridge EspInternalProtocol) ***
        // because name and machine is not the same so it's not recognized as coming from self...
        // what if we just always discard packets from 127.0.0.1 ?
        // TRYING THIS SOLUTION: mark rebroadcast opcodes with the rebroadcasting name machine and filter against that as well...
        [plist setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"name"] forKey:@"bridgeName"];
        [plist setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"]forKey:@"bridgeMachine"];
        [self rebroadcastOpcode:plist];
        
    }
    else
    {
        NSString* s = [NSString stringWithFormat:@"unable to deserialize packet of length %lu into property list (opcode)",[d length]];
        postProblem(s, self);
    }
}


-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    if([address isEqual:@"/esp/bridge/localGroup"])
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/localGroup with wrong number of parameters", self);
            return NO;
        }
        [self setLocalGroup:[d objectAtIndex:0]];
        return YES;
    }
    if([address isEqual:@"/esp/bridge/localAddress"])
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/localAddress with wrong number of parameters", self);
            return NO;
        }
        [self setLocalAddress:[d objectAtIndex:0]];
        return YES;
    }
    if([address isEqual:@"/esp/bridge/localPort"])
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/localPort with wrong number of parameters", self);
            return NO;
        }
        [self changeLocalPort:[[d objectAtIndex:0] intValue]];
        return YES;
    }
    else if([address isEqual:@"/esp/bridge/remoteAddress"])
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/remoteAddress with wrong number of parameters", self);
            return NO;
        }
        [self setRemoteAddress:[d objectAtIndex:0]];
        return YES;
    }
    else if([address isEqual:@"/esp/bridge/remotePort"])   
    {
        if([d count] != 1)
        {
            postProblem(@"received /esp/bridge/remotePort with wrong number of parameters", self);
            return NO;
        }
        [self setRemotePort:[d objectAtIndex:0]];
        return YES;
    }
    return NO;
}

@end