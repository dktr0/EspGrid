//
//  EspOscSubscribers.m
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2015 by David Ogborn.
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

#import "EspOscSubscribers.h"

@implementation EspOscSubscribers
@synthesize socket;

-(id) init
{
    self = [super init];
    subscribers = [[NSMutableArray alloc] init];
    return self;
}

-(void) dealloc
{
    [subscribers release];
    [super dealloc];
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    if([address isEqual:@"/esp/subscribe"])
    {
        if([d count] == 0)
        {
            [self subscribeHost:h port:p];
        }
        else if([d count] == 1)
        {
            [self subscribeHost:h port:[[d objectAtIndex:0] intValue]];
        }
        else if([d count] == 2)
        {
            [self subscribeHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue]];
        }
        else
        {
            postProblem(@"received /esp/subscribe with too many parameters", self);
        }
        return YES;
    }
    if([address isEqual:@"/esp/unsubscribe"])
    {
        if([d count] == 0)
        {
            [self unsubscribeHost:h port:p];
        }
        else if([d count] == 1)
        {
            [self unsubscribeHost:h port:[[d objectAtIndex:0] intValue]];
        }
        else if([d count] == 2)
        {
            [self unsubscribeHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue]];
        }
        else
        {
            postProblem(@"received /esp/unsubscribe with too many parameters", self);
        }
        return YES;
    }
    return NO;
}

-(void) subscribeHost:(NSString*)host port:(int)port
{
    for(NSArray *x in subscribers)
    {
        NSString* h = [x objectAtIndex:0];
        int p = [[x objectAtIndex:1] intValue];
        if( [h isEqualToString:host] && port==p) return;
    }
    // if we get here, match was not found, so add entry
    NSArray* n = [NSArray arrayWithObjects:host,[NSNumber numberWithInt:port],nil];
    [subscribers addObject:n];
    NSLog(@"subscribed %@:%d",host,port);
}

-(void) unsubscribeHost:(NSString*)host port:(int)port
{
    NSArray* found = nil;
    for(NSArray *x in subscribers)
    {
        NSString* h = [x objectAtIndex:0];
        int p = [[x objectAtIndex:1] intValue];
        if( [h isEqualToString:host] && port==p) {
            found = x;
            break;
        }
    }
    if(found != nil) // a match was found so remove it
    {
        [subscribers removeObject:found];
        NSLog(@"unsubscribed %@:%d",host,port);
    }
}

-(int) count
{
    return (int)[subscribers count];
}

-(void) sendData:(NSData *)data
{
    NSLog(@"EspOscSubscribers sendData");
    for(NSArray *x in subscribers)
    {
        NSString* host = [x objectAtIndex:0];
        int port = [[x objectAtIndex:1] intValue];
        NSLog(@" sending to %@:%d",host,port);
        NSAssert(socket!=nil,@"socket is nil in EspOscSubscribers sendData");
        [socket sendData:data toHost:host port:port];
    }
}

@end
