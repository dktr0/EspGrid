//
//  EspPeerList.m
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

#import "EspPeerList.h" 
#import "EspGridDefs.h"

@implementation EspPeerList
@synthesize status;
@synthesize selfInPeerList;

+(EspPeerList*) peerList
{
    static EspPeerList* sharedPeerList = nil;
    if(!sharedPeerList) sharedPeerList = [[EspPeerList alloc] init];
    return sharedPeerList;
}

-(id) init {
    self = [super init];
    peers = [[NSMutableArray alloc] init];
    NSUserDefaults* x = [NSUserDefaults standardUserDefaults];
    [x addObserver:self forKeyPath:@"person" options:NSKeyValueObservingOptionNew context:nil];
    [x addObserver:self forKeyPath:@"machine" options:NSKeyValueObservingOptionNew context:nil];
    [self addSelfToPeerList];
    [self updateStatus];
    return self;
}

-(void) dealloc
{
    [peers release];
    [super dealloc];
}

-(void)addSelfToPeerList
{
    NSUserDefaults* x = [NSUserDefaults standardUserDefaults];
    EspPeer* d = [[EspPeer alloc] init];
    [d setName:[x stringForKey:@"person"]];
    [d setMachine:[x stringForKey:@"machine"]];
    [d setIp:@"unknown"];
    [d setMajorVersion:ESPGRID_MAJORVERSION];
    [d setMinorVersion:ESPGRID_MINORVERSION];
    [d setSubVersion:ESPGRID_SUBVERSION];
    [d setVersion:[NSString stringWithFormat:@"%d.%d.%d",
                   ESPGRID_MAJORVERSION,
                   ESPGRID_MINORVERSION,
                   ESPGRID_SUBVERSION]];
    [peers addObject:d];
    selfInPeerList = d;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // this is called when name/machine are changed in user defaults
    NSUserDefaults* x = [NSUserDefaults standardUserDefaults];
    [selfInPeerList setName:[x stringForKey:@"person"]];
    [selfInPeerList setMachine:[x stringForKey:@"machine"]];
}

-(EspPeer*) receivedBeacon:(EspBeaconOpcode*)opcode
{
    // find or add the peer from whom the beacon has come
    NSString* name = [NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding];
    NSString* machine = [NSString stringWithCString:opcode->header.machine encoding:NSUTF8StringEncoding];
    EspPeer* peer = [self findPeerWithName:name andMachine:machine];
    if(peer == nil) peer = [self addNewPeer:opcode]; // note: only a BEACON can add a new peer
    [self willChangeValueForKey:@"peers"];
    [peer processBeacon:opcode];
    [self didChangeValueForKey:@"peers"];
    return peer;
}

-(EspPeer*) receivedAck:(EspAckOpcode*)opcode
{
    // find or add the peer from whom the ack has come
    NSString* name = [NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding];
    NSString* machine = [NSString stringWithCString:opcode->header.machine encoding:NSUTF8StringEncoding];
    EspPeer* peer = [self findPeerWithName:name andMachine:machine];
    if(peer == nil) return nil; // note: we don't do anything with a given peer unless we have received a prior BEACON
    
    // who is the ack for?
    NSString* ackForName = [NSString stringWithCString:opcode->nameRcvd encoding:NSUTF8StringEncoding];
    NSString* ackForMachine = [NSString stringWithCString:opcode->machineRcvd encoding:NSUTF8StringEncoding];
    EspPeer* ackFor = [self findPeerWithName:ackForName andMachine:ackForMachine];
    if(ackFor == nil) { NSLog(@"ACK for unknown peer %@-%@",ackForName,ackForMachine); return nil; } // note: we don't do anything with a given peer unless we have received a prior BEACON
    
    // process the ACK within the pertinent EspPeer instance...
    [self willChangeValueForKey:@"peers"];
    if(ackFor == selfInPeerList) [peer processAckForSelf:opcode peerCount:(int)[peers count]];
    else [peer processAck:opcode forOther:ackFor];
    [self didChangeValueForKey:@"peers"];
    [peer dumpAdjustments];
    return peer;
}

-(EspPeer*) addNewPeer:(EspBeaconOpcode*)opcode
{
    // extract parameters from dictionary passed from opcode
    NSString* name = [NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding];
    NSString* machine = [NSString stringWithCString:opcode->header.machine encoding:NSUTF8StringEncoding];
    NSString* ip = [NSString stringWithCString:opcode->header.ip encoding:NSUTF8StringEncoding];
    int theirMajorVersion = opcode->majorVersion;
    int theirMinorVersion = opcode->minorVersion;
    
    // check EspGrid version of peer/sender and warn in cases of mismatch
    if(theirMajorVersion < ESPGRID_MAJORVERSION ||
       (theirMajorVersion==ESPGRID_MAJORVERSION && theirMinorVersion < ESPGRID_MINORVERSION))
    {
        NSString* s = [NSString stringWithFormat:@"%@-%@ is running old EspGrid %d.%2d",name,machine,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    else if(theirMajorVersion > ESPGRID_MAJORVERSION ||
            (theirMajorVersion==ESPGRID_MAJORVERSION && theirMinorVersion > ESPGRID_MINORVERSION))
    {
        NSString* s = [NSString stringWithFormat:@"%@-%@ is running newer EspGrid %d.%2d",name,machine,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    
    // add new peer to peerlist
    [self willChangeValueForKey:@"peers"];
    EspPeer* x = [[EspPeer alloc] init];
    [peers addObject:x];
    [self didChangeValueForKey:@"peers"];
    postLog([NSString stringWithFormat:@"adding %@-%@ at %@",name,machine,ip], self);
    [self updateStatus];
    return x;
}

-(void) updateStatus
{
    long c = [peers count];
    for(EspPeer* x in peers) [x updateLastBeaconStatus];
    if(c>1) [self setStatus:[NSString stringWithFormat:@"%ld peers on grid",c]];
    else [self setStatus:@"no peers found yet"];
}

-(EspPeer*) findPeerWithName:(NSString*)name andMachine:(NSString*)machine
{
    for(EspPeer* x in peers) if([[x name] isEqualToString:name] && [[x machine] isEqualToString:machine])
    {
        return x;
    }
    return nil;
}

@end
