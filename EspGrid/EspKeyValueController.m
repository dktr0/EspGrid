//
//  EspKeyValueController.m
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

#import "EspKeyValueController.h"
#import "EspGridDefs.h"

@implementation EspKeyValueController
@synthesize model;

+(EspKeyValueController*) keyValueController
{
    static EspKeyValueController* sharedObject = nil;
    if(!sharedObject)sharedObject = [[EspKeyValueController alloc] init];
    return sharedObject;
}

-(id) init
{
    self = [super init];
    osc = [EspOsc osc];
    network = [EspNetwork network];
    clock = [EspClock clock];
    peerList = [EspPeerList peerList];
    keyPaths = [[NSMutableArray alloc] init];
    authorityNames = [[NSMutableDictionary alloc] init];
    authorityMachines = [[NSMutableDictionary alloc] init];
    authorities = [[NSMutableDictionary alloc] init];
    timeStamps = [[NSMutableDictionary alloc] init];
    values = [[NSMutableDictionary alloc] init];
    types = [[NSMutableDictionary alloc] init];

    kvc.header.opcode = ESP_OPCODE_KVC;
    kvc.header.length = sizeof(EspKvcOpcode);
    copyNameAndMachineIntoOpcode((EspOpcode*)&kvc);

    [NSTimer scheduledTimerWithTimeInterval:0.030
                                     target:self
                                   selector:@selector(broadcastCycle:)
                                   userInfo:nil
                                    repeats:YES];
    return self;
}

-(void) dealloc
{
    [keyPaths release];
    [authorityNames release];
    [authorityMachines release];
    [authorities release];
    [timeStamps release];
    [values release];
    [types release];
    [super dealloc];
}

-(void)addKeyPath:(NSString*)keyPath type:(int)t
{
    if(t!=ESP_KVCTYPE_BOOL && t!=ESP_KVCTYPE_DOUBLE && t!=ESP_KVCTYPE_TIME && t!= ESP_KVCTYPE_INT)
      NSAssert(false,@"EspKeyValueController: attempt to addKeyPath with unrecognized type");
    [keyPaths addObject:[keyPath copy]];
    [types addObject:[NSNumber numberWithInt:t]];
    [timeStamps setObject:[NSNumber numberWithLongLong:0] forKey:keyPath];
}

-(void) setValue:(id)value forKeyPath:(NSString *)keyPath
{
    [model setValue:value forKeyPath:keyPath];
    [values setObject:value forKey:keyPath];
    [timeStamps setObject:[NSNumber numberWithLongLong:monotonicTime()] forKey:keyPath];
    EspPeer* selfInPeerList = [peerList selfInPeerList];
    [authorityNames setObject:[selfInPeerList name] forKey:keyPath];
    [authorityMachines setObject:[selfInPeerList machine] forKey:keyPath];
    [authorities setObject:selfInPeerList forKey:keyPath];
    [self broadcastKeyPath:keyPath];
}

-(void) broadcastCycle:(NSTimer*)t
{
    if(broadcastIndex >= [keyPaths count])broadcastIndex = 0;
    if([keyPaths count]> 0) [self broadcastKeyPath:[keyPaths objectAtIndex:broadcastIndex]];
    broadcastIndex++;
}

-(void) broadcastKeyPath:(NSString*)keyPath
{
    // don't broadcast values that haven't been changed/set yet (no authority)
    EspTimeType t = [[timeStamps objectForKey:keyPath] longLongValue];
    if(t == 0) return;

    // also: don't broadcast values when we aren't the authority, unless authority is AWOL...
    NSString* authorityPerson = [authorityNames objectForKey:keyPath];
    NSString* authorityMachine = [authorityMachines objectForKey:keyPath];
    EspPeer* authority = [peerList findPeerWithName:authorityPerson andMachine:authorityMachine];
    if(authority != [peerList selfInPeerList])
    {
        EspTimeType t = monotonicTime() - [authority lastBeacon];
        if(t < 10000000000) return;
    }

    copyNameAndMachineIntoOpcode((EspOpcode*)&kvc); // to fix: should only be copied when defaults change
    kvc.timeStamp = [[timeStamps objectForKey:keyPath] longLongValue];
    strncpy(kvc.keyPath,[keyPath cStringUsingEncoding:NSUTF8StringEncoding],ESP_KVC_MAXKEYLENGTH);
    kvc.keyPath[ESP_KVC_MAXKEYLENGTH-1] = 0;
    strncpy(kvc.authorityPerson,[authorityPerson cStringUsingEncoding:NSUTF8StringEncoding],ESP_MAXNAMELENGTH);
    kvc.authorityPerson[ESP_MAXNAMELENGTH-1] = 0;
    strncpy(kvc.authorityMachine,[authorityMachine cStringUsingEncoding:NSUTF8StringEncoding],ESP_MAXNAMELENGTH);
    kvc.authorityMachine[ESP_MAXNAMELENGTH-1] = 0;
    kvc.type = [[types objectForKey:keyPath] intValue];
    if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.boolValue = [[values objectForKey:keyPath] boolValue];
    else if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.doubleValue = [[values objectForKey:keyPath] doubleValue];
    else if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.timeValue = [[values objectForKey:keyPath] longLongValue];
    else if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.intValue = [[values objectForKey:keyPath] intValue];
    else NSAssert(false,@"invalid kvc type in EspKeyValueController broadcast method");
    [network sendOpcode:(EspOpcode*)kvc];
}

-(EspTimeType) clockAdjustmentForAuthority:(NSString*)keyPath
{
    EspPeer* auth = [authorities objectForKey:keyPath];
    return [clock adjustmentForPeer:auth];
}

-(void) handleOpcode:(EspOpcode *)opcode
{
    NSAssert(opcode->opcode == ESP_OPCODE_KVC,@"EspKeyValueController sent unrecognized opcode");
    EspKvcOpcode* rcvd = (EspKvcOpcode*)opcode;

    // extract and sanitize opcode elements
    if(rcvd->timeStamp == 0) return; // ignore initial, non-actioned settings
    NSString* keyPath = [NSString stringWithCString:opcode->keyPath encoding:NSUTF8StringEncoding];
    if([types objectForKey:keyPath] == NULL) {
      postLog([NSString stringWithFormat:@"dropping KVC with unregistered keypath %@",keyPath],self);
      return;
    }
    NSString* authorityPerson = [NSString stringWithCString:opcode->authorityPerson encoding:NSUTF8StringEncoding];
    NSString* authorityMachine = [NSString stringWithCString:opcode->authorityMachine encoding:NSUTF8StringEncoding];
    id value;
    if(rcvd->type == ESP_KVCTYPE_BOOL) value = [NSNumber numberWithBool:rcvd->value.boolValue];
    else if(rcvd->type == ESP_KVCTYPE_DOUBLE) value = [NSNumber numberWithDouble:rcvd->value.doubleValue];
    else if(rcvd->type == ESP_KVCTYPE_TIME) value = [NSNumber numberWithLongLong:rcvd->value.timeValue];
    else if(rcvd->type == ESP_KVCTYPE_INT) value = [NSNumber numberWithInt:rcvd->value.intValue];
    else {
      postLog([NSString stringWithFormat:@"dropping KVC with unrecognized type field %d",rcvd->type],self);
      return;
    }
    EspPeer* newAuthority = [peerList findPeerWithName:authorityPerson andMachine:authorityMachine];
    if(newAuthority == nil) {
        postLog([NSString stringWithFormat:@"dropping KVC with unknown authority): %@-%@",
                 authorityPerson,authorityMachine], self);
        return;
    }
    EspTimeType t2 = rcvd->timeStamp + [clock adjustmentForPeer:newAuthority];
    EspPeer* oldAuthority = [authorities objectForKey:keyPath];
    EspTimeType t1 = 0;
    if(oldAuthority != nil) t1 = [[timeStamps objectForKey:keyPath] longLongValue] + [clock adjustmentForPeer:oldAuthority];
    if(t2 > t1)
    {
        [model setValue:value forKeyPath:keyPath];
        [values setObject:value forKey:keyPath];
        [timeStamps setObject:[NSNumber numberWithLongLong:rcvd->timeStamp] forKey:keyPath];
        [authorityNames setObject:[authorityPerson copy] forKey:keyPath];
        [authorityMachines setObject:[authorityMachine copy] forKey:keyPath];
        [authorities setObject:newAuthority forKey:keyPath];
        postLog([NSString stringWithFormat:@"new value %@ for key %@",keyPath,value],self);
    }
}

-(void) handleOldOpcode:(NSDictionary*)d
{
    NSAssert(false,@"empty old opcode handler in EspKeyValueController called");
}

@end
