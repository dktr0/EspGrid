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
#import "EspNetwork.h"

@implementation EspPeer

// these are updated by BEACON opcode
@synthesize name;
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

@synthesize validBeaconReceived, validAckForSelfReceived, validAckForOtherReceived;

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
    copyPersonIntoOpcode((EspOpcode*)&peerinfo);
    
    validBeaconReceived = false;
    validAckForSelfReceived = false;
    validAckForOtherReceived = false;
    
    return self;
}

-(void) dealloc
{
    free(adjustments);
    [averageLatencyObj release];
    [refBeaconAverageObj release];
    [super dealloc];
}

-(void) personChanged
{
    copyPersonIntoOpcode((EspOpcode*)&peerinfo);
}

-(void) processBeacon:(EspBeaconOpcode*)opcode
{
    if(opcode->header.receiveTime == 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid beacon with receive timestamp 0 from %@",name];
        postCritical(m,self);
        return;
    }
    validBeaconReceived = true;
    [self setName:[NSString stringWithCString:opcode->header.name encoding:NSUTF8StringEncoding]];
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
    
    if(beaconSend <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with beaconSend timestamp <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    if(beaconReceive <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with beaconReceive timestamp <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    if(ackSend <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with ackSend timestamp <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    if(ackReceive <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with ackReceive timestamp <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    if(ackPrepare <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with ackPrepare duration <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    if(roundtrip <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with roundtrip duration <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    if(recentLatency <= 0)
    {
        NSString* m = [NSString stringWithFormat:@"*** invalid ACK for self with recentLatency <= 0 from %@",name];
        postCritical(m,self);
        return;
    }
    validAckForSelfReceived = true;

    adjustments[0] = ackReceive - (ackSend + recentLatency);
    adjustments[1] = ackReceive - (ackSend + lowestLatency);
    adjustments[2] = ackReceive - (ackSend + averageLatency);

}

-(void) dumpAdjustments
{
    NSString* m = [NSString stringWithFormat:@"adjustments for %@",name];
    postProtocolLow(m,nil);
    for(int x=0;x<5;x++)
    {
        m = [NSString stringWithFormat:@" adjustment[%d]=%lld",x,adjustments[x]];
        postProtocolLow(m,nil);
    }
}

-(void) processAck:(EspAckOpcode*)opcode forOther:(EspPeer*)other
{
    // when we receive an ACK to someone else' beacon, we can use the information it contains
    // to form reference beacon style estimates of the difference between their clocks and our clocks

    if([other validBeaconReceived] == false)
    {
        NSString* m = [NSString stringWithFormat:@"*** ignoring ACK for %@ received from %@ without prior beacon received",[other name],name];
        postProtocolHigh(m,self);
        return;
    }
    
    long incomingBeaconCount = opcode->beaconCount;
    long storedBeaconCount = [other beaconCount];
    if(incomingBeaconCount == storedBeaconCount)
    {
        EspTimeType incomingBeaconTime = opcode->beaconReceive;
        EspTimeType storedBeaconTime = [other lastBeacon];
        if(incomingBeaconTime <= 0)
        {
            NSString* m = [NSString stringWithFormat:@"*** invalid ACK for %@ from %@ with incomingBeaconTime <= 0",[other name],name];
            postCritical(m,self);
            return;
        }
        if(storedBeaconTime <= 0)
        {
            NSString* m = [NSString stringWithFormat:@"*** invalid ACK for %@ from %@ with incomingBeaconTime <= 0",[other name],name];
            postCritical(m,self);
            return;
        }
        if((storedBeaconTime - incomingBeaconTime) <= 0)
        {
            NSString* m = [NSString stringWithFormat:@"*** invalid ACK for %@ from %@ with incomingBeaconTime <= 0",[other name],name];
            postCritical(m,self);
            return;
        }
        adjustments[3] = refBeacon = storedBeaconTime - incomingBeaconTime;
        adjustments[4] = refBeaconAverage = [refBeaconAverageObj push:refBeacon];
        validAckForOtherReceived = true;
    }
    else
    {
        NSString* m = [NSString stringWithFormat:@"ignoring ack for %@ from %@ with mismatched beacon count",[other name],name];
        postProtocolHigh(m,self);
        return;
    }
}

-(EspTimeType) adjustmentForSyncMode:(int)mode
{
    if(mode == 0 || mode == 1 || mode == 2)
    {
        if(validAckForSelfReceived == false)
        {
            NSString* m = [NSString stringWithFormat:@"can't provide mode %d adjustment for %@ prior to ACK for self",mode,name];
            postProtocolHigh(m,self);
            return 0;
        }
        return adjustments[mode];
    }
    else if(mode == 3 || mode == 4)
    {
        if(validAckForOtherReceived == false && validAckForSelfReceived == false)
        {
            NSString* m = [NSString stringWithFormat:@"can't provide mode %d adjustment for %@ prior to any ACKs (self or other)",mode,name];
            postProtocolHigh(m,self);
            return 0;
        }
        if(validAckForOtherReceived == false)
        {
            if(mode == 3) mode = 0;
            else if(mode == 4) mode = 2;
        }
        return adjustments[mode];
    }
    else
    {
        postCritical(@"*** attempt to query non-existent clock adjustment mode ***",self);
        return 0;
    }
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

-(void) issuePeerInfoOpcode
{
    EspNetwork* network = [EspNetwork network];
    peerinfo.recentLatency = recentLatency;
    peerinfo.lowestLatency = lowestLatency;
    peerinfo.averageLatency = averageLatency;
    peerinfo.refBeacon = refBeacon;
    peerinfo.refBeaconAverage = refBeaconAverage;
    [network sendOpcode:(EspOpcode*)&peerinfo];
}

@end
