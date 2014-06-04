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
@synthesize lastBeaconMonotonic,lastBeaconSystem;
@synthesize lastBeaconStatus;

// these are updated by ACK opcode
@synthesize recentLatencyMM,lowestLatencyMM,averageLatencyMM;
@synthesize recentLatencyMS,lowestLatencyMS,averageLatencyMS;
@synthesize recentLatencySM,lowestLatencySM,averageLatencySM;
@synthesize recentLatencySS,lowestLatencySS,averageLatencySS;
@synthesize refBeaconMonotonic,refBeaconMonotonicAverage;

-(id) init
{
    self = [super init];
    adjustments = malloc(sizeof(EspTimeType)*15);
    memset(adjustments,0,sizeof(EspTimeType)*15);
    averageLatencyMMobj = [[EspMovingAverage alloc] initWithLength:12];
    averageLatencyMSobj = [[EspMovingAverage alloc] initWithLength:12];
    averageLatencySMobj = [[EspMovingAverage alloc] initWithLength:12];
    averageLatencySSobj = [[EspMovingAverage alloc] initWithLength:12];
    lowestLatencyMM = 100000000000; // 100 seconds should be enough?
    lowestLatencyMS = 100000000000; // really should just replace with a flag
    lowestLatencySM = 100000000000; // that automatically places first measurement as lowest
    lowestLatencySS = 100000000000;
    refBeaconMonotonicAverageObj = [[EspMovingAverage alloc] initWithLength:12];
    return self;
}

-(void) dealloc
{
    free(adjustments);
    [averageLatencyMMobj release];
    [averageLatencyMSobj release];
    [averageLatencySMobj release];
    [averageLatencySSobj release];
    [refBeaconMonotonicAverageObj release];
    [super dealloc];
}

-(void) processBeacon:(NSDictionary*)d
{
    [self setName:[d objectForKey:@"name"]];
    [self setMachine:[d objectForKey:@"machine"]];
    [self setIp:[d objectForKey:@"ip"]];
    [self setMajorVersion:[[d objectForKey:@"majorVersion"] intValue]];
    [self setMinorVersion:[[d objectForKey:@"minorVersion"] intValue]];
    [self setSubVersion:[[d objectForKey:@"subVersion"] intValue]];
    [self setVersion:[NSString stringWithFormat:@"%d.%d.%d",majorVersion,minorVersion,subVersion]];
    [self setSyncMode:[[d objectForKey:@"syncMode"] intValue]];
    [self setBeaconCount:[[d objectForKey:@"beaconCount"] intValue]];
    [self setLastBeaconMonotonic:[[d objectForKey:@"packetReceiveTime"] longLongValue]];
    [self setLastBeaconSystem:[[d objectForKey:@"packetReceiveTimeSystem"] longLongValue]];
    [self setLastBeaconStatus:@"<10s"];
}

-(void) processAckForSelf:(NSDictionary*)d peerCount:(int)count
{
    // when we receive an ACK to our own beacon, we can use the information it contains
    // to form various estimates of the latency between ourselves and the peer sending the ACK
    // Note: this method does not verify that the ACK is indeed meant for this peer
    
    // these are clock measurements included with the ACK opcode, or added by send/receive
    EspTimeType beaconSendMonotonic = [[d objectForKey:@"beaconSendMonotonic"] longLongValue];
    EspTimeType beaconSendSystem = [[d objectForKey:@"beaconSendSystem"] longLongValue];
    EspTimeType beaconReceiveMonotonic = [[d objectForKey:@"beaconReceiveMonotonic"] longLongValue];
    EspTimeType beaconReceiveSystem = [[d objectForKey:@"beaconReceiveSystem"] longLongValue];
    EspTimeType ackSendMonotonic = [[d objectForKey:@"sendTime"] longLongValue];
    EspTimeType ackSendSystem = [[d objectForKey:@"sendTimeSystem"] longLongValue];
    EspTimeType ackReceiveMonotonic = [[d objectForKey:@"receiveTime"] longLongValue];
    EspTimeType ackReceiveSystem = [[d objectForKey:@"receiveTimeSystem"] longLongValue];
    
    // from these times we can calculate roundtrip time, and interval peer spent preparing ACK, on each clock
    // and then each of those can be tracked immediately, lowest value or average value
    EspTimeType ackPrepareMonotonic = ackSendMonotonic - beaconReceiveMonotonic;
    EspTimeType ackPrepareSystem = ackSendSystem - beaconReceiveSystem;
    EspTimeType roundtripMonotonic = ackReceiveMonotonic - beaconSendMonotonic;
    EspTimeType roundtripSystem = ackReceiveSystem - beaconSendSystem;
    
    recentLatencyMM = (roundtripMonotonic - ackPrepareMonotonic) / 2;
    recentLatencyMS = (roundtripMonotonic - ackPrepareSystem) / 2;
    recentLatencySM = (roundtripSystem - ackPrepareMonotonic) / 2;
    recentLatencySS = (roundtripSystem - ackPrepareSystem) / 2;
    if(recentLatencyMM < lowestLatencyMM) lowestLatencyMM = recentLatencyMM;
    if(recentLatencyMS < lowestLatencyMS) lowestLatencyMS = recentLatencyMS;
    if(recentLatencySM < lowestLatencySM) lowestLatencySM = recentLatencySM;
    if(recentLatencySS < lowestLatencySS) lowestLatencySS = recentLatencySS;
    averageLatencyMM = [averageLatencyMMobj push:recentLatencyMM];
    averageLatencyMS = [averageLatencyMSobj push:recentLatencyMS];
    averageLatencySM = [averageLatencySMobj push:recentLatencySM];
    averageLatencySS = [averageLatencySSobj push:recentLatencySS];
    
    adjustments[1] = ackReceiveMonotonic - (ackSendMonotonic + recentLatencyMM);
    adjustments[2] = ackReceiveMonotonic - (ackSendMonotonic + lowestLatencyMM);
    adjustments[3] = ackReceiveMonotonic - (ackSendMonotonic + averageLatencyMM);
    adjustments[6] = ackReceiveMonotonic - (ackSendMonotonic + recentLatencyMS);
    adjustments[7] = ackReceiveMonotonic - (ackSendMonotonic + recentLatencySM);
    adjustments[8] = ackReceiveMonotonic - (ackSendMonotonic + recentLatencySS);
    adjustments[9] = ackReceiveMonotonic - (ackSendMonotonic + lowestLatencyMS);
    adjustments[10] = ackReceiveMonotonic - (ackSendMonotonic + lowestLatencySM);
    adjustments[11] = ackReceiveMonotonic - (ackSendMonotonic + lowestLatencySS);
    adjustments[12]= ackReceiveMonotonic - (ackSendMonotonic + averageLatencyMS);
    adjustments[13]= ackReceiveMonotonic - (ackSendMonotonic + averageLatencySM);
    adjustments[14]= ackReceiveMonotonic - (ackSendMonotonic + averageLatencySS);
    // if there are fewer than 3 peers, fill in temp. values for ref beacon adjustments
    // based on these latency calculations
    if(count<3)
    {
        adjustments[4] = adjustments[1];
        adjustments[5] = adjustments[3];
    }
}

-(void) dumpAdjustments
{
    NSLog(@"adjustments for %@-%@:",name,machine);
    for(int x=0;x<15;x++)
    {
        NSLog(@" adjustment[%d]=%lld",x,adjustments[x]);
    }
}

-(void) processAck:(NSDictionary*)d forOther:(EspPeer*)other
{
    // when we receive an ACK to someone else' beacon, we can use the information it contains
    // to form reference beacon style estimates of the difference between their clocks and our clocks
        
    int incomingBeaconCount = [[d objectForKey:@"beaconCount"] intValue];
    int storedBeaconCount = [other beaconCount];
    if(incomingBeaconCount == storedBeaconCount)
    {
        EspTimeType incomingBeaconTime = [[d objectForKey:@"beaconReceiveMonotonic"] longLongValue];
        EspTimeType storedBeaconTime = [other lastBeaconMonotonic];
        // [adjustmentsLock lock];
        adjustments[4] = refBeaconMonotonic = storedBeaconTime - incomingBeaconTime;
        adjustments[5] = refBeaconMonotonicAverage = [refBeaconMonotonicAverageObj push:refBeaconMonotonic];
        // [adjustmentsLock unlock];
        NSLog(@"confirming reference beacon calculations");
    }
    else NSLog(@"mismatched beacon counts - stored = %d, received = %d",storedBeaconCount,incomingBeaconCount);
}

-(EspTimeType) adjustmentForSyncMode:(int)mode
{
    return adjustments[mode];
}

-(void) updateLastBeaconStatus
{
    EspTimeType diff = monotonicTime() - lastBeaconMonotonic;
    if(diff < 10000000000) [self setLastBeaconStatus:@"<10s"];
    else if(diff < 30000000000) [self setLastBeaconStatus:@"<30s"];
    else if(diff < 60000000000) [self setLastBeaconStatus:@"<60s"];
    else if(diff < 120000000000) [self setLastBeaconStatus:@"<120s"];
    else [self setLastBeaconStatus:@"LOST"];
}

@end
