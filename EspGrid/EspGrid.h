//
//  EspGrid.h
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
#import "EspNetwork.h"
#import "EspBridge.h"
#import "EspOsc.h"
#import "EspClock.h"
#import "EspBeat.h"
#import "EspPeerList.h"
#import "EspChat.h"
#import "EspKeyValueController.h"
#import "EspCodeShare.h"
#import "EspMessage.h"
#import "EspQueue.h"

@interface EspGrid: NSObject <EspHandleOsc>
{
    NSString* versionString;
    NSString* title;
    BOOL highVolumePosts;
}
@property (readonly) NSString* versionString;
@property (readonly) NSString* title;
@property (assign) BOOL highVolumePosts;

+(EspGrid*) grid;
+(void) postChat:(NSString*)m;
+(void) postLog:(NSString*)m;
-(EspBeat*) beat;
-(EspCodeShare*) codeShare;
-(EspPeerList*) peerList;
-(EspBridge*) bridge;
-(EspClock*) clock;
-(EspChat*) chat;

@end
