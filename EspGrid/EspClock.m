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
    countOfBeaconsIssued = 0;
    [self sendBeacon:nil];
    return self;
}


-(void) changeSyncMode:(int)mode
{
    [self setSyncMode:mode];
    [[peerList selfInPeerList] setSyncMode:mode];
}

-(void) issueBeacon
{
    countOfBeaconsIssued++;
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init]; // was autoreleased on OSX 0.48 ???
    [d setObject:[NSNumber numberWithLong:countOfBeaconsIssued] forKey:@"beaconCount"];
    [d setObject:[NSNumber numberWithInt:ESPGRID_MAJORVERSION] forKey:@"majorVersion"];
    [d setObject:[NSNumber numberWithInt:ESPGRID_MINORVERSION] forKey:@"minorVersion"];
    [d setObject:[NSNumber numberWithInt:ESPGRID_SUBVERSION] forKey:@"subVersion"];
    [d setObject:[NSNumber numberWithInt:syncMode] forKey:@"syncMode"];
    [network sendOpcode:ESP_OPCODE_BEACON withDictionary:d];
    [peerList updateStatus];
}

-(void) issueAck:(NSDictionary*)d
{
    // argument d contains what was received from an incoming BEACON opcode
    // some of that is bundled back into the outgoing ACK opcode
    NSMutableDictionary* d2 = [[NSMutableDictionary alloc] init];
    [d2 setValue:[d objectForKey:@"name"] forKey:@"nameRcvd"];
    [d2 setValue:[d objectForKey:@"machine"]forKey:@"machineRcvd"];
    [d2 setValue:[d objectForKey:@"originAddress"] forKey:@"ipRcvd"];
    [d2 setValue:[[d objectForKey:@"beaconCount"] copy] forKey:@"beaconCount"];
    [d2 setValue:[[d objectForKey:@"sendTime"] copy] forKey:@"beaconSendMonotonic"];
    [d2 setValue:[[d objectForKey:@"sendTimeSystem"] copy] forKey:@"beaconSendSystem"];
    [d2 setValue:[[d objectForKey:@"receiveTime"] copy] forKey:@"beaconReceiveMonotonic"];
    [d2 setValue:[[d objectForKey:@"receiveTimeSystem"] copy] forKey:@"beaconReceiveSystem"];
    [network sendOpcode:ESP_OPCODE_ACK withDictionary:d2];
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

-(void) handleOpcode:(NSDictionary*)d;
{
    id opcodeObject = [d objectForKey:@"opcode"];
    if(opcodeObject == nil) { postWarning(@"asked to handle opcode without opcode field",self); }
    if(![opcodeObject isKindOfClass:[NSNumber class]]) { postWarning(@"opcode field not number",self); }
    int opcode = [opcodeObject intValue];
        
    if(opcode==ESP_OPCODE_BEACON) {
        // validate opcode fields
        NSString* name = [d objectForKey:@"name"]; VALIDATE_OPCODE_NSSTRING(name);
        NSString* machine = [d objectForKey:@"machine"]; VALIDATE_OPCODE_NSSTRING(machine);
        NSString* ip = [d objectForKey:@"originAddress"]; VALIDATE_OPCODE_NSSTRING(ip);
        NSNumber* beaconCount = [d objectForKey:@"beaconCount"]; VALIDATE_OPCODE_NSNUMBER(beaconCount);
        NSNumber* majorVersion = [d objectForKey:@"majorVersion"]; VALIDATE_OPCODE_NSNUMBER(majorVersion);
        NSNumber* minorVersion = [d objectForKey:@"minorVersion"]; VALIDATE_OPCODE_NSNUMBER(minorVersion);
        // should change later to validate received subVersion from BEACON as well
        NSNumber* syncModeObject = [d objectForKey:@"syncMode"]; VALIDATE_OPCODE_NSNUMBER(syncModeObject);
        NSNumber* sendTime = [d objectForKey:@"sendTime"]; VALIDATE_OPCODE_NSNUMBER(sendTime);
        NSNumber* sendTimeSystem = [d objectForKey:@"sendTimeSystem"]; VALIDATE_OPCODE_NSNUMBER(sendTimeSystem);
        NSNumber* receiveTime = [d objectForKey:@"receiveTime"]; VALIDATE_OPCODE_NSNUMBER(receiveTime);
        NSNumber* receiveTimeSystem = [d objectForKey:@"receiveTimeSystem"]; VALIDATE_OPCODE_NSNUMBER(receiveTimeSystem);
        // log; respond with ACK; harvest data into peerlist
        postLog([NSString stringWithFormat:@"BEACON from %@-%@ at %@",name,machine,ip],self);
        [self issueAck:d];
        [peerList receivedBeacon:d];
    }
    
    if(opcode==ESP_OPCODE_ACK) {
        // validate opcode fields
        NSString* name = [d objectForKey:@"name"]; VALIDATE_OPCODE_NSSTRING(name);
        NSString* machine = [d objectForKey:@"machine"]; VALIDATE_OPCODE_NSSTRING(machine);
        NSString* ip = [d objectForKey:@"originAddress"]; VALIDATE_OPCODE_NSSTRING(ip);
        NSString* nameRcvd = [d objectForKey:@"nameRcvd"]; VALIDATE_OPCODE_NSSTRING(nameRcvd);
        NSString* machineRcvd = [d objectForKey:@"machineRcvd"]; VALIDATE_OPCODE_NSSTRING(machineRcvd);
        NSString* ipRcvd = [d objectForKey:@"ipRcvd"]; VALIDATE_OPCODE_NSSTRING(ipRcvd);
        NSNumber* beaconCountObject = [d objectForKey:@"beaconCount"]; VALIDATE_OPCODE_NSNUMBER(beaconCountObject);
        NSNumber* beaconSendMonotonic = [d objectForKey:@"beaconSendMonotonic"]; VALIDATE_OPCODE_NSNUMBER(beaconSendMonotonic);
        NSNumber* beaconSendSystem = [d objectForKey:@"beaconSendSystem"]; VALIDATE_OPCODE_NSNUMBER(beaconSendSystem);
        NSNumber* beaconReceiveMonotonic = [d objectForKey:@"beaconReceiveMonotonic"]; VALIDATE_OPCODE_NSNUMBER(beaconReceiveMonotonic);
        NSNumber* beaconReceiveSystem = [d objectForKey:@"beaconReceiveSystem"]; VALIDATE_OPCODE_NSNUMBER(beaconReceiveSystem);
        NSNumber* sendTime = [d objectForKey:@"sendTime"]; VALIDATE_OPCODE_NSNUMBER(sendTime);
        NSNumber* sendTimeSystem = [d objectForKey:@"sendTimeSystem"]; VALIDATE_OPCODE_NSNUMBER(sendTimeSystem);
        NSNumber* receiveTime = [d objectForKey:@"receiveTime"]; VALIDATE_OPCODE_NSNUMBER(receiveTime);
        NSNumber* receiveTimeSystem = [d objectForKey:@"receiveTimeSystem"]; VALIDATE_OPCODE_NSNUMBER(receiveTimeSystem);
        // harvest data into peerlist
        [peerList receivedAck:d];
    }
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
