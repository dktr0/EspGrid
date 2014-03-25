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
#import "EspGridDefs.h"
#import "EspMovingAverage.h"

@interface EspPeer : NSObject
{
    // properties 
  NSString* name;
  NSString* machine;
  NSString* ip;
  int majorVersion;
  int minorVersion;
  int subVersion;
  NSString* version;
  int syncMode;
  int beaconCount;
  EspTimeType lastBeaconMonotonic,lastBeaconSystem;
  NSString* lastBeaconStatus;
  EspTimeType recentLatencyMM,recentLatencyMS,recentLatencySM,recentLatencySS;
  EspTimeType lowestLatencyMM,lowestLatencyMS,lowestLatencySM,lowestLatencySS;
  EspTimeType averageLatencyMM,averageLatencyMS,averageLatencySM,averageLatencySS;
  EspTimeType refBeaconMonotonic,refBeaconMonotonicAverage;
    // instance variables
    EspTimeType* adjustments;
    NSLock* adjustmentsLock;
    EspMovingAverage* averageLatencyMMobj;
    EspMovingAverage* averageLatencyMSobj;
    EspMovingAverage* averageLatencySMobj;
    EspMovingAverage* averageLatencySSobj;
    EspMovingAverage* refBeaconMonotonicAverageObj;
}
// these are set/updated from BEACON opcode
@property (copy) NSString* name;
@property (copy) NSString* machine;
@property (copy) NSString* ip;
@property (assign) int majorVersion;
@property (assign) int minorVersion;
@property (assign) int subVersion;
@property (copy) NSString* version;
@property (assign) int syncMode;
@property (assign) int beaconCount;
@property (assign) EspTimeType lastBeaconMonotonic,lastBeaconSystem;
@property (copy) NSString* lastBeaconStatus;

// these are set/updated from ACK opcode
@property (assign) EspTimeType recentLatencyMM,recentLatencyMS,recentLatencySM,recentLatencySS;
@property (assign) EspTimeType lowestLatencyMM,lowestLatencyMS,lowestLatencySM,lowestLatencySS;
@property (assign) EspTimeType averageLatencyMM,averageLatencyMS,averageLatencySM,averageLatencySS;
@property (assign) EspTimeType refBeaconMonotonic,refBeaconMonotonicAverage;

-(void) processBeacon:(NSDictionary*)d;
-(void) processAckForSelf:(NSDictionary*)d peerCount:(int)count;
-(void) processAck:(NSDictionary*)d forOther:(EspPeer*)other;
-(void) updateLastBeaconStatus;
-(void) dumpAdjustments;
-(EspTimeType) adjustmentForSyncMode:(int)mode;

@end
