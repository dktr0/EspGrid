//
//  EspMessage.m
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

#import "EspMessage.h"
#import "EspGridDefs.h"

@implementation EspMessage

+(EspMessage*) message
{
    static EspMessage* sharedObject = nil;
    if(!sharedObject)sharedObject = [[EspMessage alloc] init];
    return sharedObject;
}

-(id) init
{
    self = [super init];
    network = [EspNetwork network];
    osc = [EspOsc osc];
    clock = [EspClock clock];
    peerList = [EspPeerList peerList];
    queue = [[EspQueue alloc] init];
    [queue setDelegate:self];
    return self;
}

-(void) respondToQueuedItem:(id)item
{
    [osc transmit:(NSArray*)item log:NO];
}

-(void) sendMessageNow:(NSArray*)params
{
    EspTimeType t = monotonicTime();
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    [d setObject:params forKey:@"params"];
    [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
    [network sendOldOpcode:ESP_OPCODE_OSCNOW withDictionary:d];
    [osc transmit:params log:NO];
}

-(void) sendMessageNowStamped:(NSArray*)params
{
    EspTimeType t = monotonicTime();
    NSNumber* nSecs = [NSNumber numberWithLongLong:t/1000000000];
    NSNumber* nNanos = [NSNumber numberWithDouble:t%1000000000];
    NSMutableArray* a = [NSMutableArray arrayWithArray:params];
    [a insertObject:nSecs atIndex:1]; // insert time stamp (seconds) into parameters // NOT RIGHT: needs to be translated
    [a insertObject:nNanos atIndex:2]; // insert time stamp (nanoseconds) into parameters
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    [d setObject:a forKey:@"params"];
    [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
    [network sendOldOpcode:ESP_OPCODE_OSCNOW withDictionary:d];
    [osc transmit:a log:NO];
}

-(void) sendMessageSoon:(NSArray*)params
{
    EspTimeType t = monotonicTime();
    t += 100000000; // fixed latency for now (100ms), change this later (should be maximum real latency from peerlist)
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    [d setObject:params forKey:@"params"];
    [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
    [network sendOldOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d];
    [queue addItem:params atTime:t];
}


-(void) sendMessageSoonStamped:(NSArray*)params
{
    EspTimeType t = monotonicTime();
    t += 100000000; // fixed latency for now (100ms), change this later (should be maximum real latency from peerlist)
    NSNumber* n = [NSNumber numberWithLongLong:t];
    NSMutableArray* a = [NSMutableArray arrayWithArray:params];
    [a insertObject:n atIndex:1]; // insert time stamp into parameters
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    [d setObject:a forKey:@"params"];
    [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
    [network sendOldOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d];
    [queue addItem:a atTime:t];
}

-(void) sendMessageFuture:(NSArray*)params
{
    EspTimeType t = monotonicTime();
    EspTimeType iSecs = [[params objectAtIndex:0] longLongValue];
    EspTimeType iNanos = [[params objectAtIndex:1] longLongValue];
    EspTimeType i = iSecs*1000000000+iNanos;
    NSLog(@"%lld",i+t);
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    NSMutableArray* a = [NSMutableArray arrayWithArray:params];
    [a removeObjectAtIndex:0]; // remove time increment parameter (seconds)
    [a removeObjectAtIndex:0]; // remove time increment parameter (nanoseconds)
    [d setObject:a forKey:@"params"];
    [d setObject:[NSNumber numberWithLongLong:t+i] forKey:@"time"];
    [network sendOldOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d];
    [queue addItem:a atTime:t+i];
}

-(void) sendMessageFutureStamped:(NSArray*)params
{
    EspTimeType t = monotonicTime();
    EspTimeType iSecs = [[params objectAtIndex:0] floatValue];
    EspTimeType iNanos = [[params objectAtIndex:1] longLongValue];
    EspTimeType i = iSecs*1000000000+iNanos;
    NSNumber* nSecs = [NSNumber numberWithLongLong:(t+i)/1000000000];
    NSNumber* nNanos = [NSNumber numberWithLongLong:(t+i)%1000000000];
    NSMutableArray* a = [NSMutableArray arrayWithArray:params];
    [a removeObjectAtIndex:0]; // remove time increment parameter (seconds)
    [a removeObjectAtIndex:0]; // remove time increment parameter (nanoseconds)
    [a insertObject:nSecs atIndex:1]; // insert time stamp (seconds) into parameters
    [a insertObject:nNanos atIndex:2]; // insert time stamp (nanoseconds) into parameters
    NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
    [d setObject:a forKey:@"params"];
    [d setObject:[NSNumber numberWithLongLong:t+i] forKey:@"time"];
    [network sendOldOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d];
    [queue addItem:a atTime:t+i];
}

-(void) handleOpcode:(EspOpcode *)opcode
{
    NSAssert(false,@"empty new opcode handler called");
}

-(void) handleOldOpcode:(NSDictionary*)d;
{
    int opcode = [[d objectForKey:@"opcode"] intValue];

    if(opcode==ESP_OPCODE_OSCNOW) {
        NSMutableArray* params = [NSMutableArray arrayWithArray:[d objectForKey:@"params"]];
        [osc transmit:params log:NO];
        return;
    }
    if(opcode==ESP_OPCODE_OSCFUTURE) {
        EspTimeType t = [[d objectForKey:@"time"] longLongValue]; // trigger time in other's terms
        NSString* name = [d objectForKey:@"name"];
        EspPeer* peer = [peerList findPeerWithName:name];
        if(peer == nil)
        {
            NSString* m = [NSString stringWithFormat:@"dropping OSCFUTURE from unknown peer %@",name];
            postProtocolLow(m,self);
            return;
        }
        EspTimeType adjustment = [clock adjustmentForPeer:peer];
        if(adjustment == 0)
        {
            NSString* m = [NSString stringWithFormat:@"dropping OSCFUTURE because clock adjustment 0 for peer %@",name];
            postProtocolLow(m,self);
            return;
        }
        EspTimeType t2 = t + adjustment;
        NSMutableArray* params = [NSMutableArray arrayWithArray:[d objectForKey:@"params"]];
        // [params addObject:[d objectForKey:@"time"]]; // append timestamp as final parameter
        // NSLog(@" description of params=%@",[params description]);
        [queue addItem:params atTime:t2];
    }
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)params fromHost:(NSString*)h port:(int)p
{
    if([address isEqualToString:@"/esp/msg/now"])
    {
        [self sendMessageNow:params];
        return YES;
    }
    else if([address isEqualToString:@"/esp/msg/nowStamp"])
    {
        [self sendMessageNowStamped:params];
        return YES;
    }
    else if([address isEqualToString:@"/esp/msg/soon"])
    {
        [self sendMessageSoon:params];
        return YES;
    }
    else if([address isEqualToString:@"/esp/msg/soonStamp"])
    {
        [self sendMessageSoonStamped:params];
        return YES;
    }
    else if([address isEqualToString:@"/esp/msg/future"])
    {
        [self sendMessageFuture:params];
        return YES;
    }
    else if([address isEqualToString:@"/esp/msg/futureStamp"])
    {
        [self sendMessageFutureStamped:params];
        return YES;
    }
    return NO;
}


@end
