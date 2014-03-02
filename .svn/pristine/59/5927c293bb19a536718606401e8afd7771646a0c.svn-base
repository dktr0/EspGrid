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

@interface EspPeer : NSObject

// these are set/updated from BEACON opcode
@property (atomic,copy) NSString* name;
@property (atomic,copy) NSString* machine;
@property (atomic,copy) NSString* ip;
@property (atomic,assign) int majorVersion;
@property (atomic,assign) int minorVersion;
@property (atomic,assign) int syncMode;
@property (atomic,assign) int beaconCount;
@property (atomic,assign) EspTimeType lastBeaconMonotonic,lastBeaconSystem;
@property (atomic,copy) NSString* lastBeaconStatus;

// these are set/updated from ACK opcode
@property (atomic,assign) EspTimeType recentLatencyMM,recentLatencyMS,recentLatencySM,recentLatencySS;
@property (atomic,assign) EspTimeType lowestLatencyMM,lowestLatencyMS,lowestLatencySM,lowestLatencySS;
@property (atomic,assign) EspTimeType averageLatencyMM,averageLatencyMS,averageLatencySM,averageLatencySS;
@property (atomic,assign) EspTimeType refBeaconMonotonic,refBeaconMonotonicAverage;
@property (atomic,assign) EspTimeType* adjustments;

-(void) processBeacon:(NSDictionary*)d;
-(void) processAckForSelf:(NSDictionary*)d peerCount:(int)count;
-(void) processAck:(NSDictionary*)d forOther:(EspPeer*)other;
-(void) updateLastBeaconStatus;
-(void) dumpAdjustments;

@end
