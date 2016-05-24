//
//  EspClock.m
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

#import "EspClock.h"
#import "EspGridDefs.h"
#import <Foundation/Foundation.h>

@implementation EspClock
@synthesize syncMode;
@synthesize flux;
@synthesize fluxStatus;

+(EspClock*) clock
{
    static EspClock* sharedClock = nil;
    if(!sharedClock)sharedClock = [[EspClock alloc] init];
    return sharedClock;
}

-(id) init
{
    peerList = [EspPeerList peerList];
    network = [EspNetwork network];
    osc = [EspOsc osc];
    for(int x=0;x<1024;x++)
    {
        fluxTimes[x] = 0;
        fluxValues[x] = 0;
    }
    fluxIndex = 0;
    [self setFluxStatus:@"---"];
    self = [super init];
    
    // setup BEACON opcode
    beacon.header.opcode = ESP_OPCODE_BEACON;
    beacon.header.length = sizeof(EspBeaconOpcode);
    beacon.majorVersion = ESPGRID_MAJORVERSION;
    beacon.minorVersion = ESPGRID_MINORVERSION;
    beacon.subVersion = ESPGRID_SUBVERSION;
    
    // setup ACK opcode
    ack.header.opcode = ESP_OPCODE_ACK;
    ack.header.length = sizeof(EspAckOpcode);
        
    countOfBeaconsIssued = 0;
    [self sendBeacon:nil]; // issue initial beacon
    
    return self;
}


-(void) changeSyncMode:(int)mode
{
    NSLog(@"changing clock mode to %d",mode);
    [self setSyncMode:mode];
    [[peerList selfInPeerList] setSyncMode:mode];
}

-(void) issueBeacon
{
    countOfBeaconsIssued++;
    beacon.beaconCount = countOfBeaconsIssued;
    beacon.syncMode = syncMode;
    [network sendOpcode:(EspOpcode*)&beacon];
    [peerList updateStatus];
}

-(void) issueAck:(EspBeaconOpcode*)b
{
    strncpy(ack.nameRcvd,b->header.name,16);
    ack.nameRcvd[15] = 0; // i.e. make sure strings have only 15 readable characters in them
    strncpy(ack.machineRcvd,b->header.machine,16);
    ack.machineRcvd[15] = 0;
    strncpy(ack.ipRcvd,b->header.ip,16);
    ack.ipRcvd[15] = 0;
    ack.beaconCount = b->beaconCount;
    ack.beaconSend = b->header.sendTime;
    ack.beaconReceive = b->header.receiveTime;
    [network sendOpcode:(EspOpcode*)&ack];
}

-(void) sendBeacon:(NSTimer*)t
{
    [self issueBeacon];
    NSTimeInterval nextBeacon = 1.0 + (4.0*((double)rand()/RAND_MAX)); // beacons 1 - 5 seconds apart
    [NSTimer scheduledTimerWithTimeInterval:nextBeacon
                                     target:self
                                   selector:@selector(sendBeacon:)
                                   userInfo:nil
                                    repeats:NO];
}

-(void) handleOpcode:(EspOpcode*)opcode;
{
    NSAssert(opcode->opcode == ESP_OPCODE_BEACON || opcode->opcode == ESP_OPCODE_ACK || opcode->opcode == ESP_OPCODE_PEERINFO,@"EspClock sent unrecognized opcode");
    
    if(opcode->opcode==ESP_OPCODE_BEACON) {
        postLog([NSString stringWithFormat:@"BEACON from %s-%s at %s",opcode->name,opcode->machine,opcode->ip],self);
        [self issueAck:(EspBeaconOpcode*)opcode];
        [peerList receivedBeacon:(EspBeaconOpcode*)opcode];
    }
    
    if(opcode->opcode==ESP_OPCODE_ACK) {
        EspPeer* peer = [peerList receivedAck:(EspAckOpcode*)opcode]; // harvest data into peerlist
        [peer issuePeerInfoOpcode];
    }
    
    if(opcode->opcode==ESP_OPCODE_PEERINFO) {
        [peerList receivedPeerInfo:(EspPeerInfoOpcode*)opcode];
    }
}

-(void) handleOldOpcode:(NSDictionary*)opcode
{
    NSAssert(false,@"empty old opcode handler called");
}

-(EspTimeType) adjustmentForPeer:(EspPeer*)peer
{
    if(peer) return [peer adjustmentForSyncMode:[self syncMode]];
    else {
        NSString* l = [NSString stringWithFormat:
                       @"nil peer(%@,%@,%@) in [EspClock adjustmentForPeer]",
                       [peer name],[peer machine],[peer ip],nil];
        postWarning(l, self);
        return 0;
    }
}

-(void)updateflux:(EspTimeType)adjToAdj
{
    EspTimeType now = monotonicTime();
    fluxTimes[fluxIndex] = now;
    if(adjToAdj<0)adjToAdj*=-1;
    fluxIndex++;
    if(fluxIndex>=1024)fluxIndex=0;
    EspTimeType total = 0;
    EspTimeType threshold = now - 5000000000;
    for(int x=0;x<1024;x++)if(fluxTimes[x]>threshold)total = total + fluxValues[x];
    [self setValue:[NSNumber numberWithLongLong:total] forKey:@"flux"];
    NSLog(@"flux = %llu",flux);
    if(flux==0) [self setFluxStatus:@"stable"];
    else if(flux<1000) [self setFluxStatus:[NSString stringWithFormat:@"%lld nanos",flux]];
    else if(flux<1000000) [self setFluxStatus:[NSString stringWithFormat:@"%lld micros",flux/1000]];
    else if(flux<1000000000) [self setFluxStatus:[NSString stringWithFormat:@"%lld millis",flux/1000000]];
    else [self setFluxStatus:@">1second"];
}

@end
