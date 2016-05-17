//
//  EspPeer.h
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2014 by David Ogborn.
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
#import "EspOpcode.h"
#import "EspGridDefs.h"
#import "EspNetwork.h"
#import "EspMovingAverage.h"

@interface EspPeer : NSObject
{
    // properties 
  NSString* name;
  NSString* machine;
  NSString* ip;
  char majorVersion;
  char minorVersion;
  char subVersion;
  NSString* version;
  char syncMode;
  long beaconCount;
  EspTimeType lastBeacon;
  NSString* lastBeaconStatus;
  EspTimeType recentLatency;
  EspTimeType lowestLatency;
  EspTimeType averageLatency;
  EspTimeType refBeacon,refBeaconAverage;

    EspPeerInfoOpcode peerinfo;
    
    // instance variables
    EspTimeType* adjustments;
    EspMovingAverage* averageLatencyObj;
    EspMovingAverage* refBeaconAverageObj;
}
// these are set/updated from BEACON opcode
@property (copy) NSString* name;
@property (copy) NSString* machine;
@property (copy) NSString* ip;
@property (assign) char majorVersion;
@property (assign) char minorVersion;
@property (assign) char subVersion;
@property (copy) NSString* version;
@property (assign) char syncMode;
@property (assign) long beaconCount;
@property (assign) EspTimeType lastBeacon;
@property (copy) NSString* lastBeaconStatus;

// these are set/updated from ACK opcode
@property (assign) EspTimeType recentLatency;
@property (assign) EspTimeType lowestLatency;
@property (assign) EspTimeType averageLatency;
@property (assign) EspTimeType refBeacon,refBeaconAverage;

-(void) processBeacon:(EspBeaconOpcode*)opcode;
-(void) processAckForSelf:(EspAckOpcode*)opcode peerCount:(int)count;
-(void) processAck:(EspAckOpcode*)opcode forOther:(EspPeer*)other;
-(void) updateLastBeaconStatus;
-(void) dumpAdjustments;
-(EspTimeType) adjustmentForSyncMode:(int)mode;

@end
