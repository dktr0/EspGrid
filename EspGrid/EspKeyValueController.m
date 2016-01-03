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
    [super dealloc];
}

-(void)addKeyPath:(NSString*)keyPath
{
    [keyPaths addObject:[keyPath copy]];
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
    NSString* authorityName = [authorityNames objectForKey:keyPath];
    NSString* authorityMachine = [authorityMachines objectForKey:keyPath];
    EspPeer* authority = [peerList findPeerWithName:authorityName andMachine:authorityMachine];
    if(authority != [peerList selfInPeerList])
    {
        EspTimeType t = monotonicTime() - [authority lastBeacon];
        if(t < 10000000000) return;
    }
    // all conditions have been met: so broadcast the opcode
    NSMutableDictionary* d = [[[NSMutableDictionary alloc] init] autorelease];
    [d setObject:keyPath forKey:@"keyPath"];
    [d setObject:[authorityNames objectForKey:keyPath] forKey:@"authorityName"];
    [d setObject:[authorityMachines objectForKey:keyPath] forKey:@"authorityMachine"];
    [d setObject:[[timeStamps objectForKey:keyPath] copy] forKey:@"timeStamp"];
    [d setObject:[[values objectForKey:keyPath] copy] forKey:@"value"];
    [network sendOldOpcode:ESP_OPCODE_KVC withDictionary:d];
}

-(EspTimeType) clockAdjustmentForAuthority:(NSString*)keyPath
{
    EspPeer* auth = [authorities objectForKey:keyPath];
    return [clock adjustmentForPeer:auth];
}

-(void) handleOpcode:(EspOpcode *)opcode
{
    NSAssert(false,@"empty new opcode handler called");
}

-(void) handleOldOpcode:(NSDictionary*)d
{
    int opcode = [[d objectForKey:@"opcode"] intValue];
    
    if(opcode == ESP_OPCODE_KVC) // a broadcast dictionary value from somewhere 
    {
        NSNumber* timeStamp = [d objectForKey:@"timeStamp"]; VALIDATE_OPCODE_NSNUMBER(timeStamp);
        if([timeStamp longLongValue] == 0) return; // ignore initial, non-actioned settings
        NSString* keyPath = [d objectForKey:@"keyPath"]; VALIDATE_OPCODE_NSSTRING(keyPath);
        id value = [d objectForKey:@"value"];
        if(value == nil) { postWarning(@"received KVC with value==nil",self); return; }
        NSString* name = [d objectForKey:@"authorityName"]; VALIDATE_OPCODE_NSSTRING(name);
        NSString* machine = [d objectForKey:@"authorityMachine"]; VALIDATE_OPCODE_NSSTRING(machine);
        EspPeer* newAuthority = [peerList findPeerWithName:name andMachine:machine];
        if(newAuthority == nil)
        {
            postLog([NSString stringWithFormat:@"dropping KVC (unknown authority): %@-%@",
                     name,machine], self);
			return;
        }
        EspTimeType t2 = [timeStamp longLongValue] + [clock adjustmentForPeer:newAuthority];
        EspPeer* oldAuthority = [authorities objectForKey:keyPath];
        EspTimeType t1;
        if(oldAuthority != nil) t1 = [[timeStamps objectForKey:keyPath] longLongValue] + [clock adjustmentForPeer:oldAuthority]; else t1 = 0;
        if(t2 > t1)
        {
            [model setValue:value forKeyPath:keyPath];
            [values setObject:value forKey:keyPath];
            [timeStamps setObject:[timeStamp copy] forKey:keyPath];
            [authorityNames setObject:[name copy] forKey:keyPath];
            [authorityMachines setObject:[machine copy] forKey:keyPath];
            [authorities setObject:newAuthority forKey:keyPath];
            postLog([NSString stringWithFormat:@"new value %@ for key %@",keyPath,value],self);
        }
    }
}

@end
