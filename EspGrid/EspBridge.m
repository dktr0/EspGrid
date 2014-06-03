//
//  EspBridge.m
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

#import "EspBridge.h"
#import "EspGridDefs.h"
#import "EspSocket.h"

@implementation EspBridge
@synthesize localGroup, localAddress;
@synthesize remoteClaimedAddress, remoteClaimedPort, remotePackets;

-(void) sendDictionaryWithTimes:(NSDictionary*)d
{
    NSMutableDictionary* e = [NSMutableDictionary dictionaryWithDictionary:d];
    [e setObject:localGroup forKey:@"localGroup"];
    [e setObject:localAddress forKey:@"localAddress"];
    [e setObject:[NSNumber numberWithInt:port] forKey:@"localPort"];
    [super sendDictionaryWithTimes:e];
}

-(void) afterDataReceived:(NSDictionary *)plist
{
    remotePacketsLong++;
    [self setRemotePackets:[NSString stringWithFormat:@"%ld",remotePacketsLong]];
    [self setRemoteClaimedAddress:[plist objectForKey:@"localAddress"]];
    [self setRemoteClaimedPort:[plist objectForKey:@"localPort"]];
    [super afterDataReceived:plist];
}

@end
