//
//  EspPeerList.h
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
#import "EspGridDefs.h"
#import "EspPeer.h"

@interface EspPeerList : NSObject
{
    NSMutableArray* peers;
    NSLock* peersLock;
    NSString* status;
    EspPeer* selfInPeerList;
}
@property (nonatomic,assign) NSString* status;
@property (nonatomic,assign) EspPeer* selfInPeerList;

-(EspPeer*) receivedBeacon:(NSDictionary*)d;
-(EspPeer*) receivedAck:(NSDictionary*)d;
-(EspPeer*) findPeerWithName:(NSString*)name andMachine:(NSString*)machine;
-(EspPeer*) addNewPeer:(NSDictionary*)d;
-(void) addSelfToPeerList;
-(void) updateStatus;
@end

