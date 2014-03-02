//
//  EspClock.h
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
#import "EspOsc.h"
#import "EspPeerList.h"

@interface EspClock : NSObject <EspHandleOpcode>
{
    int countOfBeaconsIssued;
    int syncMode;
    EspTimeType fluxTimes[1024];
    EspTimeType fluxValues[1024];
    int fluxIndex;
    EspPeerList* peerList;
    EspInternalProtocol* udp;
    EspOsc* osc;
    NSString* syncModeName;
    EspTimeType flux;
    NSString* fluxStatus;
}
@property (nonatomic,assign) EspPeerList* peerList;
@property (nonatomic,assign) EspInternalProtocol* udp;
@property (nonatomic,assign) EspOsc* osc;
@property (assign) NSString* syncModeName;
@property (assign) EspTimeType flux;
@property (retain) NSString* fluxStatus;

-(void) changeSyncMode:(int)mode;
-(EspTimeType) adjustmentForPeer:(EspPeer*)peer;
-(void) updateflux:(EspTimeType)adjToAdj;

@end
