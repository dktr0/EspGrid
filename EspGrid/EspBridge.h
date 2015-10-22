//
//  EspBridge.h
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2015 by David Ogborn.
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
#import "EspChannel.h"

@interface EspBridge : EspChannel
{
    NSLock* bridgeLock;
    NSString* localGroup;
    NSString* localAddress;
    NSString* remoteClaimedAddress;
    NSString* remoteClaimedPort;
    NSString* remotePackets;
    unsigned long remotePacketsLong;
}
#ifdef _WIN32
// atomic not available on WIN32/MINGW?
@property (copy) NSString* localGroup;
@property (copy) NSString* localAddress;
@property (copy) NSString* remoteClaimedAddress;
@property (copy) NSString* remoteClaimedPort;
@property (copy) NSString* remotePackets;
#else
@property (atomic,copy) NSString* localGroup;
@property (atomic,copy) NSString* localAddress;
@property (atomic,copy) NSString* remoteClaimedAddress;
@property (atomic,copy) NSString* remoteClaimedPort;
@property (atomic,copy) NSString* remotePackets;
#endif

@end
