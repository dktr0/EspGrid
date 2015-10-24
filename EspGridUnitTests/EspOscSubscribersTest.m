//
//  EspOscSubscribersTest.m
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

#import "EspOscSubscribersTest.h"

@implementation EspOscSubscribers

-(void) setUp
{
    subscribers = [[EspOscSubscribers alloc] init];
}

-(void) tearDown
{
    [subscribers release];
}

-(void) testSubscriberCountStartsAtZero
{
    STAssertEquals(0,[subscribers count],@"new OscSubscribers object should have count 0");
}

-(void) testSubscribeIncreasesCount
{
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    STAssertEquals(1,[subscribers count],@"after subscribeHost count should be 1");
}

-(void) testAdditionalSubscribeIncreasesCount
{
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    [subscribers subscribeHost:@"10.0.0.1" port:5560];
    STAssertEquals(2,[subscribers count],@"after two x subscribeHost count should be 2");
}

-(void) testDuplicateSubscribeDoesntIncreaseCount
{
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    STAssertEquals(1,[subscribers count],@"after duplicate subscriptions count should be 1");
}

-(void) testUnsubscribingReturnsCountToZero
{
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    [subscribers unsubscribeHost:@"127.0.0.1" port:5511];
    STAssertEquals(0,[subscribers count],@"unsubscribing should return count to 0");
}

-(void) testUnsubscribingUnmatchedHostRetainsCount
{
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    [subscribers unsubscribeHost:@"10.0.0.4" port:5511];
    STAssertEquals(1,[subscribers count],@"unsubscribing unmatched host should retain count");
}

-(void) testUnsubscribingUnmatchedPortRetainsCount
{
    [subscribers subscribeHost:@"127.0.0.1" port:5511];
    [subscribers unsubscribeHost:@"127.0.0.1" port:5560];
    STAssertEquals(1,[subscribers count],@"unsubscribing unmatched port should retain count");
}

@end
