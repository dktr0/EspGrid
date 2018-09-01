//
//  EspKeyValueController.h
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
#import "EspNetwork.h"
#import "EspClock.h"
#import "EspPeerList.h"

@interface EspKeyValueController : NSObject <EspNetworkDelegate>
{
    NSMutableArray* keyPaths;
    NSMutableDictionary* authorityNames;
    NSMutableDictionary* authorities;
    NSMutableDictionary* timeStamps;
    NSMutableDictionary* values;
    NSMutableDictionary* types;
    NSMutableDictionary* scopes;
    int broadcastIndex;
    NSObject* model;
    EspOsc* osc;
    EspNetwork* network;
    EspClock* clock;
    EspPeerList* peerList;

    EspIntOpcode intOpcode;
    EspFloatOpcode floatOpcode;
    EspTimeOpcode timeOpcode;
    EspStringOpcode stringOpcode;
    EspMetreOpcode metreOpcode;
}
@property (nonatomic,assign) NSObject* model;
-(void) addKeyPath:(NSString*)keyPath type:(int)t scope:(int)s;
-(void) broadcastKeyPath:(NSString*)keyPath;
-(EspTimeType) clockAdjustmentForAuthority:(NSString*)keyPath;
+(EspKeyValueController*) keyValueController;
@end
