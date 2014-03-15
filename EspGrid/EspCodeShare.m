//
//  EspCodeShare.m
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

#import "EspCodeShare.h"
#import "EspGridDefs.h"

@implementation  EspCodeShare
@synthesize udp;
@synthesize osc;
@synthesize clock;
@synthesize items;
@synthesize requestedShare;


-(id) init
{
    self = [super init];
    items = [[NSMutableArray alloc] init];
    itemsLock = [[NSLock alloc] init];
    return self;
}

-(NSUInteger) countOfShares
{
    return [items count];
}

-(void) shareCode:(NSString*)code withTitle:(NSString*)title 
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:code title:title timeStamp:monotonicTime()];
    // *** NOTE: we have stamped codeshare items with local monotonic time
    // but we have not reworked codeshare system to adjust local times based on measured differences
    [self willChangeValueForKey:@"items"];
    [itemsLock lock];
    [items addObject:item];
    [itemsLock unlock];
    [self didChangeValueForKey:@"items"];
    [item announceOnUdp:udp];
}

-(NSString*) getOrRequestItem:(EspCodeShareItem*)item
{
    return [item getOrRequestContentOnUdp:udp];
}

-(void) handleAnnounceShare:(NSDictionary*)d
{
    // 1. validate info in received opcode - if anything is missing or awry, abort with a warning
    NSString* name = [d objectForKey:@"sourceName"];
    if(name == nil) { postWarning(@"received ANNOUNCE_SHARE with no name",self); return; }
    if(![name isKindOfClass:[NSString class]]) { postWarning(@"received ANNOUNCE_SHARE with name not NSString",self); return; }
    if([name length]==0){ postWarning(@"received ANNOUNCE_SHARE with zero length name",self); return; }
    
    NSString* machine = [d objectForKey:@"sourceMachine"];
    if(machine == nil) { postWarning(@"received ANNOUNCE_SHARE with no machine",self); return; }
    if(![machine isKindOfClass:[NSString class]]) { postWarning(@"received ANNOUNCE_SHARE with machine not NSString",self); return; }
    if([machine length]==0){ postWarning(@"received ANNOUNCE_SHARE with zero length machine",self); return; }
    
    NSNumber* timeStamp = [d objectForKey:@"timeStamp"];
    if(timeStamp == nil) { postWarning(@"received ANNOUNCE_SHARE with no timeStamp",self); return; }
    if(![timeStamp isKindOfClass:[NSNumber class]]) { postWarning(@"received ANNOUNCE_SHARE with timeStamp not NSNumber",self); return; }
    
    NSString* title = [d objectForKey:@"title"];
    if(title == nil) { postWarning(@"received ANNOUNCE_SHARE with no title",self); return; }
    if(![title isKindOfClass:[NSString class]]) { postWarning(@"received ANNOUNCE_SHARE with title not NSString",self); return; }
    if([title length]==0){ postWarning(@"received ANNOUNCE_SHARE with zero length title",self); return; }

    NSNumber* length = [d objectForKey:@"length"];
    if(length == nil) { postWarning(@"received ANNOUNCE_SHARE with no length",self); return; }
    if(![length isKindOfClass:[NSNumber class]]) { postWarning(@"received ANNOUNCE_SHARE with length not NSNumber",self); return; }
    if([length longValue]<=0){ postWarning(@"received ANNOUNCE_SHARE with length <= 0",self); return; }

    // 2. see if this item is already in local array - if it is, ignore...
    EspCodeShareItem* item = nil;
    [itemsLock lock];
    for(EspCodeShareItem* x in items)
    {
        if([x isEqualToName:name machine:machine timeStamp:timeStamp])
        {
            item = x;
            break;
        }
    }
   
    // 3. if item is not already present, then create a new EspCodeShareItem and add it to local array
    if(item == nil)
    {
        item = [EspCodeShareItem createWithGridSource:name
                                              machine:machine
                                                title:title
                                            timeStamp:[timeStamp doubleValue]
                                               length:[length longValue]];
        [self willChangeValueForKey:@"items"];
        [items addObject:item];
        [self didChangeValueForKey:@"items"];
        NSString *log = [NSString stringWithFormat:@"received ANNOUNCE_SHARE from %@-%@ for timeStamp %@",name,machine,timeStamp];
        postLog(log, self);
    }
    [itemsLock unlock];
}


-(void) handleRequestShare:(NSDictionary*)d
{
    NSString* sourceName = [d objectForKey:@"sourceName"];
    NSString* sourceMachine = [d objectForKey:@"sourceMachine"];
    EspTimeType timeStamp = [[d objectForKey:@"timeStamp"] doubleValue];
    [itemsLock lock];
    for(EspCodeShareItem* x in items)
    {
        if([[x sourceName] isEqualToString:sourceName] &&
           [[x sourceMachine] isEqualToString:sourceMachine] &&
           [x timeStamp] == timeStamp)
        {
            [x deliverAllOnUdp:udp];
            [itemsLock unlock];
            return;
        }
    }
    [itemsLock unlock];
}


-(void) handleDeliverShare:(NSDictionary*)d
{
    NSString* sourceName = [d objectForKey:@"sourceName"];
    NSString* sourceMachine = [d objectForKey:@"sourceMachine"];
    EspTimeType timeStamp = [[d objectForKey:@"timeStamp"] doubleValue];

    EspCodeShareItem* item;
    [itemsLock lock];
    for(EspCodeShareItem* x in items)
    {
        if([[x sourceName] isEqualToString:sourceName] &&
           [[x sourceMachine] isEqualToString:sourceMachine] &&
           [x timeStamp] == timeStamp)
        {
            item = x;
            break;
        }
    }
    if(item == nil)
    {
        [itemsLock unlock];
        return; // ? for now... later, receiving delivery of unknown items should start an entry for those items
    }
    NSString* fragment = [d objectForKey:@"fragment"];
    unsigned long index = [[d objectForKey:@"index"] longValue];
    [item addFragment:fragment index:index];
    [itemsLock unlock];
    // [self copyShareToClipboardIfRequested:item]; // factoring this out for cross-platform dvpmt
    NSLog(@"receiving DELIVER_SHARE for %@-%@ with timeStamp %lld (%ld of %ld)",
          sourceName,sourceMachine,timeStamp,index+1,[item nFragments]);
}


-(BOOL) handleOpcode:(NSDictionary*)d;
{
    int opcode = [[d objectForKey:@"opcode"] intValue];
    
    if(opcode == ESP_OPCODE_ANNOUNCESHARE) // receiving ANNOUNCE_SHARE
    {
        [self handleAnnounceShare:d];
        return YES;
    }
    else if(opcode == ESP_OPCODE_REQUESTSHARE) // receiving REQUEST_SHARE
    {
        NSString* l = [NSString stringWithFormat:@"receiving REQUEST_SHARE for %@ on %@-%@",
                       [d valueForKey:@"timeStamp"],[d valueForKey:@"sourceName"],[d valueForKey:@"sourceMachine"]];
        postLog(l,self);
        // we should change this so that any machine can respond to a request if it has the goods...
        NSString* ourName = [[NSUserDefaults standardUserDefaults] stringForKey:@"name"];
        if([[d valueForKey:@"sourceName"] isEqual:ourName]) 
        {
            NSString* ourMachine = [[NSUserDefaults standardUserDefaults] stringForKey:@"machine"];
            if([[d valueForKey:@"sourceMachine"] isEqual:ourMachine]) 
            {
                [self handleRequestShare:d];
            }
        }
        return YES;
    }
    else if(opcode == ESP_OPCODE_DELIVERSHARE) // receiving DELIVER_SHARE
    {
        [self handleDeliverShare:d];
        return YES;
    }
    
    return NO;
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    if([address isEqualToString:@"/esp/codeShare/post"])
    {
        if([d count]!=2){postProblem(@"received /esp/codeShare/post with wrong number of parameters",self); return NO;}
        [osc logReceivedMessage:address fromHost:h port:p];
        [self shareCode:[d objectAtIndex:1] withTitle:[d objectAtIndex:0]];
        return YES;
    }
    return NO;
}

@end
