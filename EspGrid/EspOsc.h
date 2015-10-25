//
//  EspOsc.h
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
#import "EspSocket.h"
#import "EspHandleOsc.h"
#import "EspOscSubscribers.h"

@interface EspOsc : NSObject <EspSocketDelegate, EspHandleOsc>
{
    EspSocket* udp;
    NSMutableArray* handlers;
    EspOscSubscribers* subscribers;
}

+(EspOsc*) osc;

-(void) addHandler:(id<EspHandleOsc>)handler forAddress:(NSString*)address;

// stuff for sending OSC
+(NSMutableData*) createOscMessage:(NSArray*)msg log:(BOOL)log;
-(void) transmit:(NSArray*)msg log:(BOOL)log; // transmit OSC to all destinations named in prefs
-(void) transmit:(NSArray*)msg toHost:(NSString*)h port:(int)p log:(BOOL)log; // transmit OSC a specific host and port
-(void) transmitData:(NSData*)d;

-(void) response:(NSString*)address value:(NSObject*)v toQuery:(NSArray*)d fromHost:(NSString*)h port:(int)p; // helper for responding to standard ../q messages with ../r messages

// generates a standard log message for a received message (use in handleOsc of handler classes)
-(void) logReceivedMessage:(NSString*)address fromHost:(NSString*)h port:(int)p;

@end
