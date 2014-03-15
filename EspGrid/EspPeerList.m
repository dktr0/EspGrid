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
@synthesize peers;
@synthesize selfInPeerList;

-(id) init {
    self = [super init];
    peers = [[NSMutableArray alloc] init];
    NSUserDefaults* x = [NSUserDefaults standardUserDefaults];
    [x addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
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
    [d setName:[x stringForKey:@"name"]];
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
    [selfInPeerList setName:[x stringForKey:@"name"]];
    [selfInPeerList setMachine:[x stringForKey:@"machine"]];
}

-(EspPeer*) receivedBeacon:(NSDictionary*)d
{
    // find or add the peer from whom the beacon has come
    NSString* name = [d objectForKey:@"name"];
    NSString* machine = [d objectForKey:@"machine"];
    EspPeer* peer = [self findPeerWithName:name andMachine:machine];
    if(peer == nil) peer = [self addNewPeer:d]; // note: only a BEACON can add a new peer
    [self willChangeValueForKey:@"peers"];
    [peer processBeacon:d];
    [self didChangeValueForKey:@"peers"];
    return peer;
}

-(EspPeer*) receivedAck:(NSDictionary*)d
{
    // find or add the peer from whom the ack has come
    NSString* name = [d objectForKey:@"name"];
    NSString* machine = [d objectForKey:@"machine"];
    EspPeer* peer = [self findPeerWithName:name andMachine:machine];
    if(peer == nil) return nil; // note: we don't do anything with a given peer unless we have received a prior BEACON
    
    // who is the ack for?
    NSString* ackForName = [d objectForKey:@"nameRcvd"];
    NSString* ackForMachine = [d objectForKey:@"machineRcvd"];
    EspPeer* ackFor = [self findPeerWithName:ackForName andMachine:ackForMachine];
    if(ackFor == nil) { NSLog(@"ACK for unknown peer"); return nil; } // note: we don't do anything with a given peer unless we have received a prior BEACON
    
    // process the ACK within the pertinent EspPeer instance...
    [self willChangeValueForKey:@"peers"];
    if(ackFor == selfInPeerList) [peer processAckForSelf:d peerCount:(int)[peers count]];
    else [peer processAck:d forOther:ackFor];
    [self didChangeValueForKey:@"peers"];
    [peer dumpAdjustments];
    return peer;
}

-(EspPeer*) addNewPeer:(NSDictionary*)d
{
    // extract parameters from dictionary passed from opcode
    NSString* name = [d objectForKey:@"name"];
    NSString* machine = [d objectForKey:@"machine"];
    NSString* ip = [d objectForKey:@"ip"];
    int theirMajorVersion = [[d objectForKey:@"majorVersion"] intValue];
    int theirMinorVersion = [[d objectForKey:@"minorVersion"] intValue];
    
    // check EspGrid version of peer/sender and warn in cases of mismatch
    if(theirMajorVersion < ESPGRID_MAJORVERSION ) 
    {
        NSString* s = [NSString stringWithFormat:@"%@-%@ is running old EspGrid %d.%2d",name,machine,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    else if(theirMajorVersion > ESPGRID_MAJORVERSION )
    {
        NSString* s = [NSString stringWithFormat:@"%@-%@ is running newer EspGrid %d.%2d",name,machine,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    else if(theirMinorVersion < ESPGRID_MINORVERSION)
    {
        NSString* s = [NSString stringWithFormat:@"%@-%@ is running old EspGrid %d.%2d",name,machine,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    else if(theirMinorVersion > ESPGRID_MINORVERSION)
    {
        NSString* s = [NSString stringWithFormat:@"%@-%@ is running newer EspGrid %d.%2d",name,machine,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    
    // add new peer to peerlist
    [self willChangeValueForKey:@"peers"];
    EspPeer* x = [[EspPeer alloc] init];
    [x setName:name];
    [x setMachine:machine];
    [x setIp:ip];
    [x setMajorVersion:theirMajorVersion];
    [x setMinorVersion:theirMinorVersion];
    [peers addObject:x];
    [self didChangeValueForKey:@"peers"];
    postLog([NSString stringWithFormat:@"adding %@-%@ at %@",name,machine,ip], self);
    [self updateStatus];
    return x;
}

-(void) checkAllLastBeaconStatuses
{
    for(EspPeer* x in peers) [x updateLastBeaconStatus];
}


-(EspPeer*) findPeerWithName:(NSString*)name andMachine:(NSString*)machine
{
    for(EspPeer* x in peers) if([[x name] isEqualToString:name] && [[x machine] isEqualToString:machine]) return x;
    return nil;
}

-(long) peerCount
{
    return [peers count];
}

-(void) updateStatus
{
    long c = [self peerCount];
    if(c>1) [self setStatus:[NSString stringWithFormat:@"%ld peers on grid",[self peerCount]]];
    else [self setStatus:@"no peers found yet"];
}

@end
