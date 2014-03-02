//
//  EspCodeShare.h
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
#import "EspOsc.h"
#import "EspInternalProtocol.h"
#import "EspClock.h"
#import "EspCodeShareItem.h"


@interface EspCodeShare : NSObject <EspHandleOpcode,EspHandleOsc>
{
  EspOsc* osc;
  EspInternalProtocol* udp;
  EspClock* clock;
  NSMutableArray* items;
  EspCodeShareItem* requestedShare;
}
@property (nonatomic,assign) EspOsc* osc;
@property (nonatomic,assign) EspInternalProtocol* udp;
@property (nonatomic,assign) EspClock* clock;
@property (readonly) NSMutableArray* items;
@property (nonatomic,assign) EspCodeShareItem* requestedShare;


-(void) shareCode:(NSString*)code withTitle:(NSString*)title;
// -(void) grabShare:(EspCodeShareItem*)item; // this is being factored out...
-(NSString*) getOrRequestItem:(EspCodeShareItem*)item; // ... in favour of this instead

-(NSUInteger) countOfShares;


@end


