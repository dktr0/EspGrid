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
    authorities = [[NSMutableDictionary alloc] init];
    timeStamps = [[NSMutableDictionary alloc] init];
    values = [[NSMutableDictionary alloc] init];
    types = [[NSMutableDictionary alloc] init];

    intOpcode.header.opcode = ESP_OPCODE_INT;
    intOpcode.header.length = sizeof(EspIntOpcode);
    floatOpcode.header.opcode = ESP_OPCODE_FLOAT;
    floatOpcode.header.length = sizeof(EspFloatOpcode);
    timeOpcode.header.opcode = ESP_OPCODE_TIME;
    timeOpcode.header.length = sizeof(EspTimeOpcode);
    stringOpcode.header.opcode = ESP_OPCODE_STRING;
    stringOpcode.header.length = sizeof(EspStringOpcode);

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
    [authorities release];
    [timeStamps release];
    [values release];
    [types release];
    [super dealloc];
}

-(void)addKeyPath:(NSString*)keyPath type:(int)t
{
    if(t!=ESP_KVCTYPE_BOOL && t!=ESP_KVCTYPE_DOUBLE && t!=ESP_KVCTYPE_TIME && t!= ESP_KVCTYPE_INT && t!=ESP_KVCTYPE_BEAT)
      NSAssert(false,@"EspKeyValueController: attempt to addKeyPath with unrecognized type");
    [keyPaths addObject:[keyPath copy]];
    [types setObject:[NSNumber numberWithInt:t] forKey:keyPath];
    [timeStamps setObject:[NSNumber numberWithLongLong:0] forKey:keyPath];
}

-(void) setValue:(id)value forKeyPath:(NSString *)keyPath
{
    [model setValue:value forKeyPath:keyPath];
    [values setObject:value forKey:keyPath];
    [timeStamps setObject:[NSNumber numberWithLongLong:monotonicTime()] forKey:keyPath];
    EspPeer* selfInPeerList = [peerList selfInPeerList];
    [authorityNames setObject:[selfInPeerList name] forKey:keyPath];
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
    EspPeer* authority = [peerList findPeerWithName:authorityPerson];
    if(authority != [peerList selfInPeerList])
    {
        EspTimeType t = monotonicTime() - [authority lastBeacon];
        if(t < 10000000000) return;
    }

    copyPersonIntoOpcode((EspOpcode*)&kvc); // to fix: should only be copied when defaults change
    kvc.timeStamp = [[timeStamps objectForKey:keyPath] longLongValue];
    strncpy(kvc.keyPath,[keyPath cStringUsingEncoding:NSUTF8StringEncoding],ESP_KVC_MAXKEYLENGTH);
    kvc.keyPath[ESP_KVC_MAXKEYLENGTH-1] = 0;
    strncpy(kvc.authorityPerson,[authorityPerson cStringUsingEncoding:NSUTF8StringEncoding],ESP_MAXNAMELENGTH);
    kvc.authorityPerson[ESP_MAXNAMELENGTH-1] = 0;
    kvc.type = [[types objectForKey:keyPath] intValue];
    if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.boolValue = [[values objectForKey:keyPath] boolValue];
    else if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.doubleValue = [[values objectForKey:keyPath] doubleValue];
    else if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.timeValue = [[values objectForKey:keyPath] longLongValue];
    else if(kvc.type == ESP_KVCTYPE_BOOL) kvc.value.intValue = [[values objectForKey:keyPath] intValue];
    else if(kvc.type == ESP_KVCTYPE_BEAT) {
        id beatParams = [values objectForKey:keyPath];
        kvc.value.beatValue.on = [[beatParams objectForKey:@"on"] boolValue];
        kvc.value.beatValue.tempo = [[beatParams objectForKey:@"tempo"] doubleValue];
        kvc.value.beatValue.downbeatTime = [[beatParams objectForKey:@"downbeatTime"] longLongValue];
        kvc.value.beatValue.number = [[beatParams objectForKey:@"downbeatNumber"] intValue];
    }
    else NSAssert(false,@"invalid kvc type in EspKeyValueController broadcast method");
    [network sendOpcode:(EspOpcode*)&kvc];
}

-(EspTimeType) clockAdjustmentForAuthority:(NSString*)keyPath
{
    EspPeer* auth = [authorities objectForKey:keyPath];
    return [clock adjustmentForPeer:auth];
}

-(void) handleOpcode:(EspOpcode *)opcode
{
    NSAssert(opcode->opcode == ESP_OPCODE_INT || opcode->opcode == ESP_OPCODE_FLOAT ||
      opcode->opcode == ESP_OPCODE_TIME || opcode->opcode == ESP_OPCODE_STRING ||
      opcode->opcode == ESP_OPCODE_METRE, @"EspKeyValueController sent unrecognized opcode");

    // look at time, path and authority to determine if this is most current info or not
    EspVariableInfo* info = &(((EspIntOpcode*)opcode)->info);
    if(info->timeStamp == 0) return; // ignore initial, non-actioned settings
    info->path[ESP_MAXNAMELENGTH-1] = 0;
    NSString* path = [NSString stringWithCString:info->path encoding:NSUTF8StringEncoding];
    info->authority[ESP_MAXNAMELENGTH-1] = 0;
    NSString* authorityHandle = [NSString stringWithCString:info->authority encoding:NSUTF8StringEncoding];
    EspPeer* authority = [peerList findPeerWithName:authorityHandle];
    if(authority == nil) {
        postLog([NSString stringWithFormat:@"dropping KVC from unknown handle %@",authorityHandle], self);
        return;
    }
    EspTimeType t2 = info->timeStamp + [clock adjustmentForPeer:authority];
    EspTimeType t1 = 0;
    if(info->scope == ESP_SCOPE_GLOBAL) {
      EspPeer* oldAuthority = [authorities objectForKey:path];
      if(oldAuthority != nil) t1 = [[timeStamps objectForKey:path] longLongValue] + [clock adjustmentForPeer:oldAuthority];
    }
    else if(info->scope == ESP_SCOPE_LOCAL) t1 = [authority adjustedTimeForPath:path];
    else {
      postLog([NSString stringWithFormat:@"dropping KVC with invalid scope %d",info->scope], self);
      return;
    }
    if(t2 <= t1) return; // if this is NOT most current info, return without updating anything

    // extract value of opcode for storage
    id value;
    if(opcode->opcode == ESP_OPCODE_INT) {
      EspIntOpcode* i = (EspIntOpcode*)opcode;
      value = [NSNumber numberWithInt:i->value];
    }
    else if(opcode->opcode == ESP_OPCODE_FLOAT) {
      EspFloatOpcode* f = (EspFloatOpcode*)opcode;
      value = [NSNumber numberWithFloat:f->value];
    }
    else if(opcode->opcode == ESP_OPCODE_STRING) {
      EspStringOpcode* s = (EspStringOpcode*)opcode;
      // protect against various possible buffer over/underwrites
      if(opcode->length > sizeof(EspStringOpcode)) {
        postLog([NSString stringWithFormat:@"dropping string opcode with excessive length %d",opcode->length], self);
        return;
      }
      if(opcode->length < ((&(s->value)) - &s) {
        postLog([NSString stringWithFormat:@"dropping too-short string opcode, length=%d",opcode->length], self);
        return;
      }
      *(s+opcode->length-1)=0;
      value = [NSString stringWithCString:s->value encoding:NSUTF8StringEncoding];
    }
    else if(opcode->opcode == ESP_OPCODE_TIME) {
      EspTimeOpcode* t = (EspTimeOpcode*)opcode;
      value = [NSNumber numberWithLongLong:t->value];
    }
    else if(opcode->opcode == ESP_OPCODE_METRE) {
      EspMetreOpcode* m = (EspMetreOpcode*)opcode;
      value = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:m->value.on],@"on",
        [NSNumber numberWithFloat:m->value.tempo],@"tempo",
        [NSNumber numberWithLongLong:m->value.time],@"time",
        [NSNumber numberWithInt:m->value.beat],@"beat",nil];
    }

    // for SYSTEM scope values only, update something in the state of EspGrid
    if(info->scope == ESP_SCOPE_SYSTEM) [model setValue:value forKeyPath:path];
    // for LOCAL scope values, just store values in corresponding entry in peerList
    if(info->scope == ESP_SCOPE_LOCAL) {
      [authority storeValue:value forPath:path];
      postLog([NSString stringWithFormat:@"new value %@ for %@ from %@",value,path,authorityHandle],self);
    }
    // and for both SYSTEM and GLOBAL scope, update values stored "here"
    else {
      [values setObject:value forKey:path];
      [timeStamps setObject:[NSNumber numberWithLongLong:rcvd->timeStamp] forKey:path];
      [authorityNames setObject:[authority copy] forKey:path];
      [authorities setObject:newAuthority forKey:path];
      postLog([NSString stringWithFormat:@"new value %@ for system/global key %@",value,path],self);
    }
}

-(void) handleOldOpcode:(NSDictionary*)d
{
    NSAssert(false,@"empty old opcode handler in EspKeyValueController called");
}

@end
