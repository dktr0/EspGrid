//
//  EspBeat.h
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
#import "EspKeyValueController.h"

@interface EspBeat : NSObject <EspHandleOsc>
{
    EspKeyValueController* kvc;
    NSNumber* on;
    NSNumber* tempo;
    NSNumber* time;
    NSNumber* beat;
    NSDictionary* params;
    unsigned long beatsIssued;
}
@property (retain) NSDictionary* params;
@property (retain) NSNumber* on;
@property (retain) NSNumber* tempo;
@property (retain) NSNumber* time;
@property (retain) NSNumber* beat;

-(void) turnBeatOn;
-(void) turnBeatOff;
-(void) changeTempo:(double)newBpm;
-(EspTimeType) adjustedDownbeatTime;
+(EspBeat*) beat;

-(bool) startTicking; // for testing, returns YES if successful or already ticking
-(void) stopTicking; // for testing
			      
@end
