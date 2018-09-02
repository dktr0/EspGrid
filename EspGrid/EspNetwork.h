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
#import "EspOpcode.h"
#import "EspPeerList.h"
#import "EspChannel.h"

#define ESPUDP_MAX_HANDLERS 16

@protocol EspNetworkDelegate
-(void) handleOpcode:(EspOpcode*)opcode;
-(void) handleOldOpcode:(NSDictionary*)d;
@end

@interface EspNetwork : NSObject <EspChannelDelegate>
{
    id<EspNetworkDelegate> handlers[ESPUDP_MAX_HANDLERS];
    NSMutableArray* channels;
    EspChannel* broadcast;
    EspChannel* bridge;
    char name[ESP_MAXNAMELENGTH];
}
@property (nonatomic,assign) EspChannel* broadcast;
@property (nonatomic,assign) EspChannel* bridge;

+(EspNetwork*) network;
-(void) sendOldOpcode:(unsigned int)opcode withDictionary:(NSDictionary*)d; // old method
-(void) sendOpcode:(EspOpcode*)opcode; // new method
-(void) handleOpcode:(EspOpcode*)opcode; // new
-(void) handleOldOpcode:(NSDictionary*)d; // old
-(void) setHandler:(id)h forOpcode:(unsigned int)o;
-(void) broadcastAddressChanged; // signal that the broadcast address may have been changed
-(void) nameChanged; // signal that unique name for this instance may have changed

@end


