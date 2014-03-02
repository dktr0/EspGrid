//
//  EspMessage.h
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
#import "EspClock.h"
#import "EspInternalProtocol.h"
#import "EspOsc.h"
#import "EspQueue.h"
#import "EspPeerList.h"

@interface EspMessage : NSObject <EspQueueDelegate,EspHandleOsc,EspHandleOpcode>
{
    EspClock* clock;
    EspInternalProtocol* udp;
    EspOsc* osc;
    EspQueue* queue;
    EspPeerList* peerList;
}
@property (assign) EspClock* clock;
@property (assign) EspInternalProtocol* udp;
@property (assign) EspOsc* osc;
@property (assign) EspQueue* queue;
@property (assign) EspPeerList* peerList;

-(void) respondToQueuedItem:(id)item;

@end
