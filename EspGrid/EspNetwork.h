//
//  EspNetwork.h
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
//

#import <Foundation/Foundation.h>
#import "EspPeerList.h"
#import "EspChannel.h"
#import "EspBridge.h"

#define ESPUDP_MAX_HANDLERS 16

@protocol EspNetworkDelegate
-(void) handleOpcode:(NSDictionary*)d;
@end

@interface EspNetwork : NSObject <EspChannelDelegate>
{
    id<EspNetworkDelegate> handlers[ESPUDP_MAX_HANDLERS];
    NSMutableArray* channels;
    EspChannel* broadcast;
    EspBridge* bridge;
}
@property (nonatomic,assign) EspChannel* broadcast;
@property (nonatomic,assign) EspBridge* bridge;

+(EspNetwork*) network;
-(void) sendOpcode:(int)opcode withDictionary:(NSDictionary*)d;
-(void) handleOpcode:(NSDictionary*)d;
-(void) setHandler:(id)h forOpcode:(int)o;
-(void) broadcastAddressChanged; // signal that the broadcast address may have been changed


@end
