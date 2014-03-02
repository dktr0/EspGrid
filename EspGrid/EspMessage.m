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
@synthesize clock;
@synthesize udp;
@synthesize osc;
@synthesize queue;
@synthesize peerList;

-(void) respondToQueuedItem:(id)item
{
    [osc transmit:(NSArray*)item log:YES];
}

-(BOOL) handleOpcode:(NSDictionary*)d;
{
    int opcode = [[d objectForKey:@"opcode"] intValue];
    
    if(opcode==ESP_OPCODE_OSCNOW) {
        NSMutableArray* params = [NSMutableArray arrayWithArray:[d objectForKey:@"params"]];
        [osc transmit:params log:YES];
        return YES;
    }
    if(opcode==ESP_OPCODE_OSCFUTURE) {
        EspTimeType t = [[d objectForKey:@"time"] longLongValue]; // trigger time in other's terms
        NSString* name = [d objectForKey:@"name"];
        NSString* machine = [d objectForKey:@"machine"];
        EspPeer* peer = [peerList findPeerWithName:name andMachine:machine];
        if(peer == nil)
        {
            postLog(@"dropping OSCFUTURE from unknown peer", self);
            return NO;
        }
        EspTimeType adjustment = [clock adjustmentForPeer:peer];
        EspTimeType t2 = t + adjustment;
        NSMutableArray* params = [NSMutableArray arrayWithArray:[d objectForKey:@"params"]];
        // [params addObject:[d objectForKey:@"time"]]; // append timestamp as final parameter
        // NSLog(@" description of params=%@",[params description]);
        [queue addItem:params atTime:t2];
    }
    return NO;
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)params fromHost:(NSString*)h port:(int)p
{
    if([address isEqualToString:@"/esp/msg/now"])
    {
        [osc logReceivedMessage:address fromHost:h port:p];
        EspTimeType t = monotonicTime();
        NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
        [d setObject:params forKey:@"params"];
        [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
        [udp transmitOpcode:ESP_OPCODE_OSCNOW withDictionary:d burst:8];
        [udp transmitOpcodeToSelf:ESP_OPCODE_OSCNOW withDictionary:d];
        return YES;
    }
    
    else if([address isEqualToString:@"/esp/msg/nowStamp"])
    {
        [osc logReceivedMessage:address fromHost:h port:p];
        EspTimeType t = monotonicTime();
        NSNumber* n = [NSNumber numberWithLongLong:t];
        NSMutableArray* a = [NSMutableArray arrayWithArray:params];
        [a insertObject:n atIndex:1]; // insert time stamp into parameters
        NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
        [d setObject:a forKey:@"params"];
        [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
        [udp transmitOpcode:ESP_OPCODE_OSCNOW withDictionary:d burst:8];
        [udp transmitOpcodeToSelf:ESP_OPCODE_OSCNOW withDictionary:d];
        return YES;
    }
    
    else if([address isEqualToString:@"/esp/msg/soon"])
    {
        [osc logReceivedMessage:address fromHost:h port:p];
        EspTimeType t = monotonicTime();
        t += 100000000; // fixed latency for now (100ms), change this later (should be maximum real latency from peerlist)
        NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
        [d setObject:params forKey:@"params"];
        [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
        [udp transmitOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d burst:8];
        [udp transmitOpcodeToSelf:ESP_OPCODE_OSCFUTURE withDictionary:d];
        return YES;
    }
    
    else if([address isEqualToString:@"/esp/msg/soonStamp"])
    {
        [osc logReceivedMessage:address fromHost:h port:p];
        EspTimeType t = monotonicTime();
        t += 100000000; // fixed latency for now (100ms), change this later (should be maximum real latency from peerlist)
        NSNumber* n = [NSNumber numberWithLongLong:t];
        NSMutableArray* a = [NSMutableArray arrayWithArray:params];
        [a insertObject:n atIndex:1]; // insert time stamp into parameters
        NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
        [d setObject:a forKey:@"params"];
        [d setObject:[NSNumber numberWithLongLong:t] forKey:@"time"];
        [udp transmitOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d burst:8];
        [udp transmitOpcodeToSelf:ESP_OPCODE_OSCFUTURE withDictionary:d];
        return YES;
    }
    
    else if([address isEqualToString:@"/esp/msg/future"])
    {
        [osc logReceivedMessage:address fromHost:h port:p];
        EspTimeType t = monotonicTime();
        EspTimeType i = [[params objectAtIndex:0] floatValue];
        NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
        NSMutableArray* a = [NSMutableArray arrayWithArray:params];
        [a removeObjectAtIndex:0]; // remove time increment parameter
        [d setObject:a forKey:@"params"];
        [d setObject:[NSNumber numberWithLongLong:t+i] forKey:@"time"];
        [udp transmitOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d burst:8];
        [udp transmitOpcodeToSelf:ESP_OPCODE_OSCFUTURE withDictionary:d];
        return YES;
    }
    
    else if([address isEqualToString:@"/esp/msg/futureStamp"])
    {
        [osc logReceivedMessage:address fromHost:h port:p];
        EspTimeType t = monotonicTime();
        EspTimeType i = [[params objectAtIndex:0] floatValue];
        NSNumber* n = [NSNumber numberWithLongLong:t+i];
        NSMutableArray* a = [NSMutableArray arrayWithArray:params];
        [a removeObjectAtIndex:0]; // remove time increment parameter
        [a insertObject:n atIndex:1]; // insert time stamp into parameters
        NSMutableDictionary* d = [[NSMutableDictionary alloc] init];
        [d setObject:a forKey:@"params"];
        [d setObject:n forKey:@"time"];
        [udp transmitOpcode:ESP_OPCODE_OSCFUTURE withDictionary:d burst:8];
        [udp transmitOpcodeToSelf:ESP_OPCODE_OSCFUTURE withDictionary:d];
        return YES;
    }
    return NO;
}


@end
