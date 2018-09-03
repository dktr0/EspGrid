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
    scopes = [[NSMutableDictionary alloc] init];

    intOpcode.header.opcode = ESP_OPCODE_INT;
    intOpcode.header.length = sizeof(EspIntOpcode);
    floatOpcode.header.opcode = ESP_OPCODE_FLOAT;
    floatOpcode.header.length = sizeof(EspFloatOpcode);
    timeOpcode.header.opcode = ESP_OPCODE_TIME;
    timeOpcode.header.length = sizeof(EspTimeOpcode);
    stringOpcode.header.opcode = ESP_OPCODE_STRING;
    stringOpcode.header.length = sizeof(EspStringOpcode);
    metreOpcode.header.opcode = ESP_OPCODE_METRE;
    metreOpcode.header.length = sizeof(EspMetreOpcode);

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
    [scopes release];
    [super dealloc];
}

-(void)addKeyPath:(NSString*)keyPath type:(int)t scope:(int)s
{
    if(t!=ESP_OPCODE_INT && t!=ESP_OPCODE_FLOAT && t!=ESP_OPCODE_TIME && t!= ESP_OPCODE_STRING && t!=ESP_OPCODE_METRE)
      NSAssert(false,@"EspKeyValueController: attempt to addKeyPath with unrecognized type");
    [keyPaths addObject:[keyPath copy]];
    [types setObject:[NSNumber numberWithInt:t] forKey:keyPath];
    [scopes setObject:[NSNumber numberWithInt:s] forKey:keyPath];
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

    EspOpcode* opcode = (EspOpcode*)&intOpcode;
    EspVariableInfo* info = &intOpcode.info;
    id value = [values objectForKey:keyPath];
    int type = [[types objectForKey:keyPath] intValue];
    if(type == ESP_OPCODE_INT)
    {
        intOpcode.value = [value intValue];
        info = &intOpcode.info;
        opcode = (EspOpcode*)&intOpcode;
    }
    else if(type == ESP_OPCODE_FLOAT)
    {
        floatOpcode.value = [value floatValue];
        info = &floatOpcode.info;
        opcode = (EspOpcode*)&floatOpcode;
    }
    else if(type == ESP_OPCODE_STRING)
    {
        strncpy(stringOpcode.value,[value cStringUsingEncoding:NSUTF8StringEncoding],ESP_MAX_STRINGOPCODELENGTH);
        stringOpcode.value[ESP_MAX_STRINGOPCODELENGTH-1] = 0;
        info = &stringOpcode.info;
        opcode = (EspOpcode*)&stringOpcode;
    }
    else if(type == ESP_OPCODE_TIME)
    {
        timeOpcode.value = [value longLongValue];
        info = &timeOpcode.info;
        opcode = (EspOpcode*)&timeOpcode;
    }
    else if(type == ESP_OPCODE_METRE)
    {
        metreOpcode.metre.time = [[value objectForKey:@"time"] longLongValue]; // EspTimeType
        metreOpcode.metre.on = [[value objectForKey:@"on"] intValue]; // int32_t
        metreOpcode.metre.beat = [[value objectForKey:@"beat"] intValue]; // int32_t
        metreOpcode.metre.tempo = [[value objectForKey:@"tempo"] floatValue]; // Float32
        info = &metreOpcode.info;
        opcode = (EspOpcode*)&metreOpcode;
    }
    else NSAssert(false,@"invalid kvc type in EspKeyValueController broadcast method");
    // transfer information that all kvc opcodes have in common into the opcode
    copyPersonIntoOpcode(opcode);
    info->timeStamp = [[timeStamps objectForKey:keyPath] longLongValue];
    strncpy(info->path,[keyPath cStringUsingEncoding:NSUTF8StringEncoding],ESP_MAXNAMELENGTH);
    info->path[ESP_MAXNAMELENGTH-1] = 0;
    strncpy(info->authority,[authorityPerson cStringUsingEncoding:NSUTF8StringEncoding],ESP_MAXNAMELENGTH);
    info->authority[ESP_MAXNAMELENGTH-1] = 0;
    info->scope = [[scopes objectForKey:keyPath] intValue];
    [network sendOpcode:opcode];
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
        postProtocolHigh([NSString stringWithFormat:@"dropping KVC from unknown authority %@",authorityHandle], self);
        return;
    }
    EspTimeType t2 = info->timeStamp + [clock adjustmentForPeer:authority];
    EspTimeType t1 = 0;
    if(info->scope == ESP_SCOPE_GLOBAL || info->scope == ESP_SCOPE_SYSTEM) {
      EspPeer* oldAuthority = [authorities objectForKey:path];
      if(oldAuthority != nil) t1 = [[timeStamps objectForKey:path] longLongValue] + [clock adjustmentForPeer:oldAuthority];
    }
    else if(info->scope == ESP_SCOPE_LOCAL) t1 = [authority adjustedTimeForPath:path];
    else {
      postCritical([NSString stringWithFormat:@"dropping KVC with invalid scope %d",info->scope], self);
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
        postCritical([NSString stringWithFormat:@"dropping string opcode with excessive length %d",opcode->length], self);
        return;
      }
      /* if(opcode->length < ((&(s->value)) - &s) {
        postLog([NSString stringWithFormat:@"dropping too-short string opcode, length=%d",opcode->length], self);
        return; // not sure what this was for anymore?
      } */
//      *(s+opcode->length-1)=0;
      value = [NSString stringWithCString:s->value encoding:NSUTF8StringEncoding];
    }
    else if(opcode->opcode == ESP_OPCODE_TIME) {
      EspTimeOpcode* t = (EspTimeOpcode*)opcode;
      value = [NSNumber numberWithLongLong:t->value];
    }
    else if(opcode->opcode == ESP_OPCODE_METRE) {
      EspMetreOpcode* m = (EspMetreOpcode*)opcode;
      value = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:m->metre.on],@"on",
        [NSNumber numberWithFloat:m->metre.tempo],@"tempo",
        [NSNumber numberWithLongLong:m->metre.time],@"time",
        [NSNumber numberWithInt:m->metre.beat],@"beat",nil];
    }

    // for SYSTEM scope values only, update something in the state of EspGrid
    if(info->scope == ESP_SCOPE_SYSTEM)
    {
      //  NSLog(@"scope is SYSTEM, setting value in model");
      [model setValue:value forKeyPath:path];
    }
    // for LOCAL scope values, just store values in corresponding entry in peerList
    if(info->scope == ESP_SCOPE_LOCAL) {
       // NSLog(@"scope is LOCAL, setting value in peerlist");
      [authority storeValue:value forPath:path];
      postLog([NSString stringWithFormat:@"new value %@ for %@ from %@",value,path,authorityHandle],self);
    }
    // and for both SYSTEM and GLOBAL scope, update values stored "here"
    if(info ->scope == ESP_SCOPE_GLOBAL || info->scope == ESP_SCOPE_SYSTEM)
    {
        // NSLog(@"scope is SYSTEM/GLOBAL, updating values stored here");
        [values setObject:value forKey:path];
        [timeStamps setObject:[NSNumber numberWithLongLong:info->timeStamp] forKey:path];
        [authorityNames setObject:[[authority name] copy] forKey:path];
        [authorities setObject:authority forKey:path];
        postLog([NSString stringWithFormat:@"new value %@ for system/global key %@",value,path],self);
    }
}

-(void) handleOldOpcode:(NSDictionary*)d
{
    NSAssert(false,@"empty old opcode handler in EspKeyValueController called");
}

@end
