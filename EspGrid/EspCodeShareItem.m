//
//  EspCodeShareItem.m
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

#import "EspCodeShareItem.h"
#import "EspGridDefs.h"

@implementation EspCodeShareItem
@synthesize complete;
@synthesize title;
@synthesize content;
@synthesize timeStamp;
@synthesize contentLength;
@synthesize sourceName;
@synthesize sourceMachine;
@synthesize nFragments;


+(id)createWithLocalContent:(NSString*)c title:(NSString*)t timeStamp:(EspTimeType)ts
{
    id r = [EspCodeShareItem alloc];
    return [r initWithLocalContent:c title:t timeStamp:ts];
}

-(id)initWithLocalContent:(NSString*)c title:(NSString*)t timeStamp:(EspTimeType)ts
{
    self = [super init];
    
    NSAssert(c != nil, @"can't create local EspCodeShareItem with nil content");
    NSAssert([c length] > 0, @"can't create local EspCodeShareItem with no content");
    [self setContent:c];
    [self setContentLength:[c length]];
    nFragments = (contentLength / ESPGRID_CODESHARE_FRAGMENTSIZE)+1;
    
    NSAssert(t != nil, @"can't create local EspCodeShareItem with nil title");
    NSAssert([t length] > 0, @"can't create local EspCodeShareItem with no title");
    [self setTitle:t];
    
    NSAssert(ts > 0.0, @"can't create local EspCodeShareItem with timeStamp < 0.0");
    [self setTimeStamp:ts];
    
    [self setSourceName:[[NSUserDefaults standardUserDefaults] objectForKey:@"person"]];
    [self setSourceMachine:[[NSUserDefaults standardUserDefaults] objectForKey:@"machine"]];
    [self setComplete:YES];

    return self;
}

+(id)createWithGridSource:(NSString*)n machine:(NSString*)m title:(NSString*)t timeStamp:(EspTimeType)ts length:(unsigned long)l;
{
    id r = [EspCodeShareItem alloc];
    return [r initWithGridSource:n machine:m title:t timeStamp:ts length:l];
}

-(id)initWithGridSource:(NSString*)n machine:(NSString*)m title:(NSString*)t timeStamp:(EspTimeType)ts length:(unsigned long)l
{
    self = [super init];
    
    NSAssert(t != nil, @"can't create grid EspCodeShareItem with nil title");
    NSAssert([t length] > 0, @"can't create grid EspCodeShareItem with no title");
    [self setTitle:t];
    
    NSAssert(n != nil, @"can't create grid EspCodeShareItem with no source name");
    NSAssert([n length] > 0, @"can't create grid EspCodeShareItem with no source name");
    [self setSourceName:n];
    
    NSAssert(m != nil, @"can't create grid EspCodeShareItem with no source machine");
    NSAssert([m length] > 0, @"can't create grid EspCodeShareItem with no source machine");
    [self setSourceMachine:m];
    
    NSAssert(ts > 0.0, @"can't create grid EspCodeShareItem with 0 timestamp");
    [self setTimeStamp:ts];
    
    NSAssert(l > 0, @"can't create grid EspCodeShareItem with size <= 0");
    [self setContentLength:l];
    
    nFragments = (l / ESPGRID_CODESHARE_FRAGMENTSIZE)+1;
    fragments = [[NSMutableArray alloc] initWithCapacity:nFragments];
    for(int x=0;x<nFragments;x++) [fragments addObject:[NSNull null]];
    [self setComplete:NO];
    
    return self;
}

-(void) addFragment:(NSString*)fragment index:(unsigned long)i
{
    if([self complete]) return; // this item is already complete - no need to add fragments
    NSAssert(i < nFragments, @"index of fragment to be added to EspCodeShareItem is too high");
    if(![[fragments objectAtIndex:i] isEqual:[NSNull null]]) return; // this fragment is already stored - no need to add it twice
    
    unsigned long finalLength;
    if(i == nFragments-1) finalLength = contentLength % ESPGRID_CODESHARE_FRAGMENTSIZE;
    else finalLength = ESPGRID_CODESHARE_FRAGMENTSIZE;
    NSAssert([fragment length] == finalLength,@"fragment does not have correct length");
    
    [fragments replaceObjectAtIndex:i withObject:fragment];
    
    // check to see if all fragments are there - if any are missing return...
    for(int x=0;x<nFragments;x++) if([[fragments objectAtIndex:x] isEqual:[NSNull null]]) return;    

    // ...we only get here if all fragments are in place, so object can be completed
    NSMutableString* s = [[NSMutableString alloc] init];
    for(int x=0;x<nFragments;x++) [s appendString:[fragments objectAtIndex:x]];
    [self setContent:s];
    [self setComplete:YES];
}

-(BOOL) isEqualToName:(NSString*)n machine:(NSString*)m timeStamp:(NSNumber*)ts
{
    if(![n isEqualToString:sourceName])return NO;
    if(![m isEqualToString:sourceMachine])return NO;
    if(![ts isEqualToNumber:[NSNumber numberWithDouble:timeStamp]])return NO;
    return YES;
}

-(void) announceOnUdp:(EspNetwork*)udp
{
    NSDictionary* o = [NSDictionary dictionaryWithObjectsAndKeys:title,@"title",
                        [NSNumber numberWithDouble:timeStamp],@"timeStamp",
                       [NSNumber numberWithLong:contentLength],@"length",
                       sourceName,@"sourceName",
                       sourceMachine,@"sourceMachine",nil];
    [udp sendOpcode:ESP_OPCODE_ANNOUNCESHARE withDictionary:o];
}

-(void) requestAllOnUdp:(EspNetwork*)udp
{
    NSAssert( !complete, @"attempt to REQUEST_SHARE for complete item");
    NSDictionary* o = [NSDictionary dictionaryWithObjectsAndKeys:
                       sourceName, @"sourceName",
                       sourceMachine, @"sourceMachine",
                       [NSNumber numberWithDouble:timeStamp], @"timeStamp", nil];
    NSString* l = [NSString stringWithFormat:@"sending REQUEST_SHARE (opcode 6) for %lld on %@-%@",timeStamp,sourceName,sourceMachine];
    postLog(l, self);
    [udp sendOpcode:ESP_OPCODE_REQUESTSHARE withDictionary:o];
}

-(void) deliverAllOnUdp:(EspNetwork*)udp
{
    for(int x=0;x<nFragments;x++)[self deliverFragment:x onUdp:udp];
}

-(void) deliverFragment:(unsigned long)i onUdp:(EspNetwork*)udp
{
    NSAssert(i < nFragments, @"index of fragment to be added to EspCodeShareItem is too high");
    
    NSString* f;
    if(complete)
    {
        NSUInteger rangeStart = i * ESPGRID_CODESHARE_FRAGMENTSIZE;
        NSUInteger rangeLength;
        if(i != (nFragments-1)) rangeLength = ESPGRID_CODESHARE_FRAGMENTSIZE;
        else rangeLength = contentLength % ESPGRID_CODESHARE_FRAGMENTSIZE;
        f = [[content substringWithRange:NSMakeRange(rangeStart,rangeLength)] copy];
    }
    else
    {
        if([[fragments objectAtIndex:i] isEqual:[NSNull null]]) return; // we don't have that fragment yet - "fail" silently
        f = [[fragments objectAtIndex:i] copy];
    }
    
    NSDictionary* o = [NSDictionary dictionaryWithObjectsAndKeys:
                       sourceName,@"sourceName",sourceMachine,@"sourceMachine",[NSNumber numberWithDouble:timeStamp],@"timeStamp",
                       [NSNumber numberWithLong:i],@"index",f,@"fragment",nil];
    NSString* l = [NSString stringWithFormat:@"sending DELIVER_SHARE (opcode 7) for %lld on %@-%@ (%ld of %ld)",timeStamp,sourceName,sourceMachine,i+1,nFragments];
    postLog(l,self);
    [udp sendOpcode:ESP_OPCODE_DELIVERSHARE withDictionary:o];
    [f release];
}

-(NSString*) getOrRequestContentOnUdp:(EspNetwork*)udp
{
    if(complete)
    {
        NSAssert(content != nil, @"item content should not be nil");
        NSAssert([content isKindOfClass:[NSString class]], @"item content should be NSString");
        return content;
    }
    else [self requestAllOnUdp:udp];
    return nil;
}

@end
