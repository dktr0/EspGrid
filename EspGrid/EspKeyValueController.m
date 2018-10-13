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
    if(auth == nil)
    {
        NSString* m = [NSString stringWithFormat:@"*** no authority for keyPath %@",keyPath];
        postCritical(m,self);
        return -1; // we use -1 to signal error in this method because...
    }
    else if(auth == [peerList selfInPeerList])
    {
        return 0; // ... the value of 0 is the clock adjustment when we are the authority for something
    }
    else
    {
        EspTimeType r = [clock adjustmentForPeer:auth];
        if(r == 0) return -1;
        return r;
    }
}

-(void) handleOpcode:(EspOpcode *)opcode
{
    NSAssert(opcode->opcode == ESP_OPCODE_INT || opcode->opcode == ESP_OPCODE_FLOAT ||
      opcode->opcode == ESP_OPCODE_TIME || opcode->opcode == ESP_OPCODE_STRING ||
      opcode->opcode == ESP_OPCODE_METRE, @"EspKeyValueController sent unrecognized opcode");

    // look at time, path and authority to determine if this is most current info or not
    EspVariableInfo* info = &(((EspIntOpcode*)opcode)->info);
    info->path[ESP_MAXNAMELENGTH-1] = 0;
    NSString* path = [NSString stringWithCString:info->path encoding:NSUTF8StringEncoding];
    info->authority[ESP_MAXNAMELENGTH-1] = 0;
    NSString* authorityHandle = [NSString stringWithCString:info->authority encoding:NSUTF8StringEncoding];
    EspPeer* authority = [peerList findPeerWithName:authorityHandle];
    if(authority == nil) {
        postCritical([NSString stringWithFormat:@"dropping KVC from unknown authority %@",authorityHandle], self);
        return;
    }
    EspTimeType adjustment = [clock adjustmentForPeer:authority];
    if(adjustment == 0)
    {
        postCritical([NSString stringWithFormat:@"dropping KVC from authority %@ with clock adjustment 0",authorityHandle], self);
        return;
    }
    if(info->timeStamp == 0)
    {
        postCritical([NSString stringWithFormat:@"dropping KVC with timestamp 0 (authority %@)",authorityHandle], self);
        return; // ignore initial, non-actioned settings
    }
    EspTimeType adjustedTimeOfNewInfo = info->timeStamp + adjustment;
    
    // if we get this far, it means we are receiving information with a valid timestamp
    // and where we have valid information about the authority that has let us adjust the timestamp to our own frame of reference
    // so now we need to determine whether this is the most current information or not...
    if(info->scope == ESP_SCOPE_GLOBAL || info->scope == ESP_SCOPE_SYSTEM) {
        EspPeer* oldAuthority = [authorities objectForKey:path];
        if(oldAuthority != nil)
        { // if there is a previous authority recorded then we need to compare adjusted times for new and old information...
            EspTimeType oldAdjustment = [clock adjustmentForPeer:oldAuthority];
            if(oldAdjustment == 0)
            {
                postCritical([NSString stringWithFormat:@"dropping KVC because prior authority %@ has clock adjustment 0", [oldAuthority name]], self);
                return;
            }
            EspTimeType oldTimeStamp = [[timeStamps objectForKey:path] longLongValue];
            if(oldTimeStamp == 0)
            {
                postCritical([NSString stringWithFormat:@"dropping KVC because prior info (authority %@) has timestamp 0", [oldAuthority name]], self);
                return;
            }
            EspTimeType adjustedTimeOfOldInfo = oldTimeStamp + oldAdjustment;
            if(adjustedTimeOfOldInfo > adjustedTimeOfNewInfo)
            {
                postProtocolLow([NSString stringWithFormat:@"dropping KVC because adjusted time stamp older than previous info (authority %@)", [oldAuthority name]], self);
                return;
            }
            else if(adjustedTimeOfOldInfo == adjustedTimeOfNewInfo)
            {
                return; // silently drop opcode old time and new time are exactly identical
            }
        } // ... and if there is no previous authority then the new information must be the most current!
    }
    else if(info->scope == ESP_SCOPE_LOCAL)
    {
        postCritical(@"*** ESP_SCOPE_LOCAL not properly implemented yet",self);
        return;
    }
    else
    {
      postCritical([NSString stringWithFormat:@"*** dropping KVC with invalid scope %d",info->scope], self);
      return;
    }

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
        postCritical(@"*** ESP_SCOPE_LOCAL not properly implemented yet",self);
        return;
        // [authority storeValue:value forPath:path];
        // postLog([NSString stringWithFormat:@"new value %@ for %@ from %@",value,path,authorityHandle],self);
    }
    // and for both SYSTEM and GLOBAL scope, update values stored "here"
    if(info ->scope == ESP_SCOPE_GLOBAL || info->scope == ESP_SCOPE_SYSTEM)
    {
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
