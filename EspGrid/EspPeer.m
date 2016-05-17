//
//  EspPeer.m
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2014 by David Ogborn.
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

#import "EspPeer.h"
#import "EspMovingAverage.h"

@implementation EspPeer

// these are updated by BEACON opcode
@synthesize name;
@synthesize machine;
@synthesize ip;
@synthesize majorVersion;
@synthesize minorVersion;
@synthesize subVersion;
@synthesize version;
@synthesize syncMode;
@synthesize beaconCount;
@synthesize lastBeacon;
@synthesize lastBeaconStatus;

// these are updated by ACK opcode
@synthesize recentLatency,lowestLatency,averageLatency;
@synthesize refBeacon,refBeaconAverage;

-(id) init
{
    self = [super init];
    adjustments = malloc(sizeof(EspTimeType)*15);
    memset(adjustments,0,sizeof(EspTimeType)*15);
    averageLatencyObj = [[EspMovingAverage alloc] initWithLength:12];
    lowestLatency = 100000000000; // 100 seconds should be enough?
    refBeaconAverageObj = [[EspMovingAverage alloc] initWithLength:12];
    
    // initial setup of PEERINFO opcode
    peerinfo.header.opcode = ESP_OPCODE_PEERINFO;
    peerinfo.header.length = sizeof(EspPeerInfoOpcode);

    return self;
}

-(void) dealloc
{
    free(adjustments);
    [averageLatencyObj release];
    [refBeaconAverageObj release];
    [super dealloc];
}

-(void) processBeacon:(EspBeaconOpcode*)opcode
{
    [self setName:[NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding]];
    [self setMachine:[NSString stringWithCString:opcode->header.machine encoding:NSUTF8StringEncoding]];
    [self setIp:[NSString stringWithCString:opcode->header.ip encoding:NSUTF8StringEncoding]];
    [self setMajorVersion:opcode->majorVersion];
    [self setMinorVersion:opcode->minorVersion];
    [self setSubVersion:opcode->subVersion];
    [self setVersion:[NSString stringWithFormat:@"%d.%d.%d",majorVersion,minorVersion,subVersion]];
    [self setSyncMode:opcode->syncMode];
    [self setBeaconCount:opcode->beaconCount];
    [self setLastBeacon:opcode->header.receiveTime];
    [self setLastBeaconStatus:@"<10s"];
    // preload name, machine and ip into peerinfo opcode
    strncpy(peerinfo.peerName,opcode->header.name,16);
    peerinfo.peerName[15] = 0;
    strncpy(peerinfo.peerMachine,opcode->header.machine,16);
    peerinfo.peerMachine[15] = 0;
    strncpy(peerinfo.peerIp,opcode->header.ip,16);
    peerinfo.peerIp[15] = 0;
}

-(void) processAckForSelf:(EspAckOpcode*)opcode peerCount:(int)count
{
    // when we receive an ACK to our own beacon, we can use the information it contains
    // to form various estimates of the latency between ourselves and the peer sending the ACK
    // Note: this method does not verify that the ACK is indeed meant for this peer
    
    // these are clock measurements included with the ACK opcode, or added by send/receive
    EspTimeType beaconSend = opcode->beaconSend;
    EspTimeType beaconReceive = opcode->beaconReceive;
    EspTimeType ackSend = opcode->header.sendTime;
    EspTimeType ackReceive = opcode->header.receiveTime;
    
    // from these times we can calculate roundtrip time, and interval peer spent preparing ACK, on each clock
    // and then each of those can be tracked immediately, lowest value or average value
    EspTimeType ackPrepare = ackSend - beaconReceive;
    EspTimeType roundtrip = ackReceive - beaconSend;
    
    recentLatency = (roundtrip - ackPrepare) / 2;
    if(recentLatency < lowestLatency) lowestLatency = recentLatency;
    averageLatency = [averageLatencyObj push:recentLatency];
    
    adjustments[0] = ackReceive - (ackSend + recentLatency);
    adjustments[1] = ackReceive - (ackSend + lowestLatency);
    adjustments[2] = ackReceive - (ackSend + averageLatency);

    // if there are fewer than 3 peers, fill in temp. values for ref beacon adjustments
    // based on these latency calculations
    if(count<3)
    {
        adjustments[3] = adjustments[0];
        adjustments[4] = adjustments[2];
    }
}

-(void) dumpAdjustments
{
    NSLog(@"adjustments for %@-%@:",name,machine);
    for(int x=0;x<5;x++)
    {
        NSLog(@" adjustment[%d]=%lld",x,adjustments[x]);
    }
}

-(void) processAck:(EspAckOpcode*)opcode forOther:(EspPeer*)other
{
    // when we receive an ACK to someone else' beacon, we can use the information it contains
    // to form reference beacon style estimates of the difference between their clocks and our clocks
        
    long incomingBeaconCount = opcode->beaconCount;
    long storedBeaconCount = [other beaconCount];
    if(incomingBeaconCount == storedBeaconCount)
    {
        EspTimeType incomingBeaconTime = opcode->beaconReceive;
        EspTimeType storedBeaconTime = [other lastBeacon];
        adjustments[3] = refBeacon = storedBeaconTime - incomingBeaconTime;
        adjustments[4] = refBeaconAverage = [refBeaconAverageObj push:refBeacon];
    }
}

-(EspTimeType) adjustmentForSyncMode:(int)mode
{
    return adjustments[mode];
}

-(void) updateLastBeaconStatus
{
    EspTimeType diff = monotonicTime() - lastBeacon;
    if(diff < 10000000000) [self setLastBeaconStatus:@"<10s"];
    else if(diff < 30000000000) [self setLastBeaconStatus:@"<30s"];
    else if(diff < 60000000000) [self setLastBeaconStatus:@"<60s"];
    else if(diff < 120000000000) [self setLastBeaconStatus:@"<120s"];
    else [self setLastBeaconStatus:@"LOST"];
}

-(void) issuePeerInfoOpcode:(EspNetwork*)network
{
    peerinfo.recentLatency = recentLatency;
    peerinfo.lowestLatency = lowestLatency;
    peerinfo.averageLatency = averageLatency;
    peerinfo.refBeacon = refBeacon;
    peerinfo.refBeaconAverage = refBeaconAverage;
    [network sendOpcode:(EspOpcode*)&peerinfo];
}

@end
