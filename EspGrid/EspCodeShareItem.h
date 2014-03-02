//
//  EspCodeShareItem.h
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

#import <Foundation/Foundation.h>
#import "EspInternalProtocol.h"

#define ESPGRID_CODESHARE_FRAGMENTSIZE 128

@interface EspCodeShareItem : NSObject
{
    NSMutableArray* fragments;
    BOOL complete;
    NSString* title;
    NSString* content;
    NSString* sourceName;
    NSString* sourceMachine;
    EspTimeType timeStamp;
    unsigned long contentLength;
    unsigned long nFragments;
}
@property (assign) BOOL complete;
@property (copy) NSString* title;
@property (copy) NSString* content;
@property (copy) NSString* sourceName;
@property (copy) NSString* sourceMachine;
@property (assign) EspTimeType timeStamp;
@property (assign) unsigned long contentLength;
@property (assign) unsigned long nFragments;


+(id)createWithLocalContent:(NSString*)c title:(NSString*)t timeStamp:(EspTimeType)ts;
+(id)createWithGridSource:(NSString*)n machine:(NSString*)m title:(NSString*)t timeStamp:(EspTimeType)ts length:(unsigned long)l;
-(BOOL) isEqualToName:(NSString*)n machine:(NSString*)m timeStamp:(NSNumber*)ts;
-(void) addFragment:(NSString*)fragment index:(unsigned long)i;
-(void) announceOnUdp:(EspInternalProtocol*)udp;
-(void) requestAllOnUdp:(EspInternalProtocol*)udp;
-(void) deliverAllOnUdp:(EspInternalProtocol*)udp;
-(void) deliverFragment:(unsigned long)i onUdp:(EspInternalProtocol*)udp;
-(NSString*) getOrRequestContentOnUdp:(EspInternalProtocol*)udp;
-(id)initWithLocalContent:(NSString*)c title:(NSString*)t timeStamp:(EspTimeType)ts;
-(id)initWithGridSource:(NSString*)n machine:(NSString*)m title:(NSString*)t timeStamp:(EspTimeType)ts length:(unsigned long)l;
@end
