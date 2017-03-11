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

-(EspPeer*) receivedBeacon:(EspBeaconOpcode*)opcode
{
    // find or add the peer from whom the beacon has come
    NSString* name = [NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding];
    EspPeer* peer = [self findPeerWithName:name];
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
    EspPeer* peer = [self findPeerWithName:name];
    if(peer == nil) return nil; // note: we don't do anything with a given peer unless we have received a prior BEACON

    // who is the ack for?
    NSString* ackForName = [NSString stringWithCString:opcode->nameRcvd encoding:NSUTF8StringEncoding];
    EspPeer* ackFor = [self findPeerWithName:ackForName];
    if(ackFor == nil) { NSLog(@"ACK for unknown peer %@",ackForName); return nil; } // note: we don't do anything with a given peer unless we have received a prior BEACON

    // process the ACK within the pertinent EspPeer instance...
    [self willChangeValueForKey:@"peers"];
    if(ackFor == selfInPeerList) [peer processAckForSelf:opcode peerCount:(int)[peers count]];
    else [peer processAck:opcode forOther:ackFor];
    [self didChangeValueForKey:@"peers"];
    [peer dumpAdjustments];
    return peer;
}

-(void) receivedPeerInfo:(EspPeerInfoOpcode*)opcode
{
    NSString* name1 = [NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding];
    EspPeer* peer1 = [self findPeerWithName:name1];
    if(peer1 == nil) { // note: we don't do anything with a given peer unless we have received a prior BEACON
        postLog(@"received PEERINFO from peer before receiving BEACON from that peer",self);
        return;
    }
    NSString* name2 = [NSString stringWithCString:opcode->peerName encoding:NSUTF8StringEncoding];
    EspPeer* peer2 = [self findPeerWithName:name2];
    if(peer2 == nil) { // note: we don't do anything with a given peer unless we have received a prior BEACON
        postLog(@"received PEERINFO about a peer before receiving BEACON from that peer",self);
        return;
    }
    postLog([NSString stringWithFormat:@"PEERINFO from %s-%s re %s-%s",
             opcode->header.name,opcode->header.ip,opcode->peerName,opcode->peerIp,nil],self);
    postLog([NSString stringWithFormat:@" recentLatency=%lld",opcode->recentLatency,nil],self);
    postLog([NSString stringWithFormat:@" lowestLatency=%lld",opcode->lowestLatency,nil],self);
    postLog([NSString stringWithFormat:@" averageLatency=%lld",opcode->averageLatency,nil],self);
    postLog([NSString stringWithFormat:@" refBeacon=%lld",opcode->refBeacon,nil],self);
    postLog([NSString stringWithFormat:@" refBeaconAverage=%lld",opcode->refBeaconAverage,nil],self);
    [peer1 dumpAdjustments];
    [peer2 dumpAdjustments];
}


-(EspPeer*) addNewPeer:(EspBeaconOpcode*)opcode
{
    // extract parameters from dictionary passed from opcode
    NSString* name = [NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding];
    NSString* ip = [NSString stringWithCString:opcode->header.ip encoding:NSUTF8StringEncoding];
    char theirMajorVersion = opcode->majorVersion;
    char theirMinorVersion = opcode->minorVersion;

    // check EspGrid version of peer/sender and warn in cases of mismatch
    if(theirMajorVersion < ESPGRID_MAJORVERSION ||
       (theirMajorVersion==ESPGRID_MAJORVERSION && theirMinorVersion < ESPGRID_MINORVERSION))
    {
        NSString* s = [NSString stringWithFormat:@"%@ is running old EspGrid %hhu.%2hhu",name,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }
    else if(theirMajorVersion > ESPGRID_MAJORVERSION ||
            (theirMajorVersion==ESPGRID_MAJORVERSION && theirMinorVersion > ESPGRID_MINORVERSION))
    {
        NSString* s = [NSString stringWithFormat:@"%@ is running newer EspGrid %hhu.%2hhu",name,theirMajorVersion,theirMinorVersion];
        postWarning(s,self);
    }

    // add new peer to peerlist
    [self willChangeValueForKey:@"peers"];
    EspPeer* x = [[EspPeer alloc] init];
    [peers addObject:x];
    [self didChangeValueForKey:@"peers"];
    postLog([NSString stringWithFormat:@"adding %@ at %@",name,ip], self);
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

-(void) personChanged
{
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    [selfInPeerList setName:[defs stringForKey:@"person"]];
    for(EspPeer* x in peers) [x personChanged];
}

-(EspPeer*) findPeerWithName:(NSString*)name
{
    for(EspPeer* x in peers) if([[x name] isEqualToString:name]) return x;
    return nil;
}

@end
