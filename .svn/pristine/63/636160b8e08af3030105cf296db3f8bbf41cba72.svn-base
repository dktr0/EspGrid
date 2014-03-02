//
//  EspBridge.h
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
#import "EspHandleOpcode.h"
#import "EspSocket.h"
#import "EspOsc.h"

@interface EspBridge : NSObject <EspSocketDelegate,EspHandleOsc>
{
    EspSocket* udpReceive;
    unsigned long remotePacketsLong;
    int localPort;
    NSString* localGroup;
    NSString* localAddress;
    NSString* remoteAddress;
    NSString* remotePort;
    NSString* remoteGroup;
    NSString* remoteClaimedAddress;
    NSString* remoteClaimedPort;
    NSString* remotePackets;
    NSObject<EspHandleOpcode>* udp;
}
@property (nonatomic,copy) NSString* localGroup;
@property (nonatomic,copy) NSString* localAddress;
@property (nonatomic,copy) NSString* remoteAddress;
@property (nonatomic,copy) NSString* remotePort;
@property (nonatomic,copy) NSString* remoteGroup;
@property (nonatomic,copy) NSString* remoteClaimedAddress;
@property (nonatomic,copy) NSString* remoteClaimedPort;
@property (nonatomic,copy) NSString* remotePackets;
@property (nonatomic,assign) NSObject<EspHandleOpcode>* udp;

-(void) changeLocalPort:(int)p;

-(void) transmitOpcode:(NSDictionary*)d;
-(void) retransmitOpcode:(NSDictionary*)d;
-(void) rebroadcastOpcode:(NSDictionary*)d;
-(BOOL) active;
@end
