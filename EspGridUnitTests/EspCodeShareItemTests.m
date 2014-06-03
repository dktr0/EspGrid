//
//  EspCodeShareItemTests.m
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

#import "EspCodeShareItemTests.h"
#import "EspCodeShareItem.h"
#import "MockEspNetwork.h"

@implementation EspCodeShareItemTests

- (void)setUp
{
    [super setUp];
    
}

- (void)tearDown
{
    [super tearDown];
}

-(void)testCreatingLocalContentWithMissingFieldsThrowsException
{
    STAssertThrows([EspCodeShareItem createWithLocalContent:nil title:@"local code" timeStamp:123456.0],
                   @"creating local EspCodeShareItem with nil content should throw exception.");
    STAssertThrows([EspCodeShareItem createWithLocalContent:@"" title:@"local code" timeStamp:123456.0],
                   @"creating local EspCodeShareItem with no content should throw exception.");
    STAssertThrows([EspCodeShareItem createWithLocalContent:@"my code" title:nil timeStamp:123456.0],
                   @"creating local EspCodeShareItem with nil title should throw exception.");
    STAssertThrows([EspCodeShareItem createWithLocalContent:@"my code" title:@"" timeStamp:123456.0],
                   @"creating local EspCodeShareItem with nil title should throw exception.");
    STAssertThrows([EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:0.0],
                   @"creating local EspCodeShareItem with 0 timeStamp should throw exception.");
}

-(void)testCreatingLocalContentIsComplete
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:123456.0];
    STAssertTrue([item complete]==YES, @"an EspCodeShareItem created from local content should be complete");
}

-(void)testCreatingLocalContentHasCorrectLength
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:123456.0];
    STAssertTrue([item contentLength]==7, @"an EspCodeShareItem created from local content should show correct contentLength");
}

-(void)testCreatingShortLocalContentHasOneFragment
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:123456.0];
    STAssertTrue([item nFragments]==1, @"an EspCodeShareItem created from short local content should have nFragments==1");
}

-(void)testCreatingLocalContentAutofillsNameAndMachine
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:123456.0];
    STAssertTrue([[item sourceName] isKindOfClass:[NSString class]],@"EspCodeShareItem name should be an NSString");
    STAssertTrue([[item sourceName] length]>0, @"EspCodeShareItem name should a string with length > 0");
    STAssertTrue([[item sourceMachine] isKindOfClass:[NSString class]],@"EspCodeShareItem machine should be an NSString");
    STAssertTrue([[item sourceMachine] length]>0, @"EspCodeShareItem machine should a string with length > 0");
}


-(void)testCreatingGridSourceWithMissingFieldsThrowsException
{
    STAssertThrows([EspCodeShareItem createWithGridSource:nil machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:16000],
                                @"creating grid EspCodeShareItem with nil name should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"" machine:@"laptop"title:@"grid code" timeStamp:123456.0 length:16000],
                                @"creating grid EspCodeShareItem with no name should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"someone" machine:nil title:@"grid code" timeStamp:123456.0 length:16000], @"creating grid EspCodeShareItem with nil machine should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"someone" machine:@""title:@"grid code" timeStamp:123456.0 length:16000],
                                @"creating grid EspCodeShareItem with no machine should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:nil timeStamp:123456.0 length:16000],
                                @"creating grid EspCodeShareItem with nil title should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"" timeStamp:123456.0 length:16000],
                                @"creating grid EspCodeShareItem with no title should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:0.0 length:16000], @"creating grid EspCodeShareItem with 0 timestamp should throw exception.");
    STAssertThrows([EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:0], @"creating grid EspCodeShareItem with 0 size should throw exception.");

}

-(void)testCreatingWithGridSourceIsIncomplete
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:26];
    STAssertTrue([item complete]==NO, @"an EspCodeShareItem created from grid content should be incomplete");
}

-(void)testCreatingWithGridSourceHasCorrectLength
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:26];
    STAssertTrue([item contentLength]==26, @"an EspCodeShareItem created from grid source should show correct contentLength");
}

-(void)testCreatingWithShortGridSourceIsOneFragment
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:26];
    STAssertTrue([item nFragments]==1, @"an EspCodeShareItem created from grid source with short length should be one fragment");
}

-(void)testProvidingSingleFragmentForShortSourceIsComplete
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:26];
    NSString* fragment = @"this is a fragment of code";
    [item addFragment:fragment index:0];
    STAssertTrue([item complete]==YES, @"a short EspCodeShareItem should be complete after fragment of correct length is provided");
}

-(void)testProvidingFragmentWithHighIndexThrows
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:26];
    NSString* fragment = @"this is a fragment of code";
    STAssertThrows([item addFragment:fragment index:1],@"fragment of wrong length should throw exception");
}

-(void)testProvidingFinalFragmentOfWrongLengthThrows
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:26];
    NSString* fragment = @"this isn't 26 chars";
    STAssertThrows([item addFragment:fragment index:0],@"fragment of wrong length should throw exception");
}

-(void)testProvidingOneFragmentOfTwoDoesntCompleteItem
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:130];
    NSString* fragment = @"{}";
    [item addFragment:fragment index:1];
    STAssertTrue([item complete]==NO,@"providing just one fragment of two shouldn't make item complete");
}

-(void)testProvidingBothFragmentsOfTwoCompletesItem
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:200];
    const unichar c = 'a';
    NSString* fragment1 = [NSString stringWithCharacters:&c length:128];
    NSString* fragment2 = [NSString stringWithCharacters:&c length:72];
    [item addFragment:fragment1 index:0];
    [item addFragment:fragment2 index:1];
    STAssertTrue([item complete]==YES,@"providing both fragments of two should make item complete");
}

-(void)testMatchingNameMachineTimeStampIsEqual
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:200];
    STAssertTrue([item isEqualToName:@"someone" machine:@"laptop" timeStamp:[NSNumber numberWithDouble:123456.0]],
                 @"correctly matched name machine and timestamp should be equal");
}

-(void)testMismatchingNameMachineOrTimeStampIsNotEqual
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"wrong" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:200];
    STAssertTrue(![item isEqualToName:@"someone" machine:@"laptop" timeStamp:[NSNumber numberWithDouble:123456.0]],
                 @"mismatched name on item source should not be equal");
    item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"wrong" title:@"grid code" timeStamp:123456.0 length:200];
    STAssertTrue(![item isEqualToName:@"someone" machine:@"laptop" timeStamp:[NSNumber numberWithDouble:123456.0]],
                 @"mismatched machine on item source should not be equal");
    item = [EspCodeShareItem createWithGridSource:@"someone" machine:@"laptop" title:@"grid code" timeStamp:654321.0 length:200];
    STAssertTrue(![item isEqualToName:@"someone" machine:@"laptop" timeStamp:[NSNumber numberWithDouble:123456.0]],
                 @"mismatched timeStamp on item source should not be equal");
    
}

-(void)testAnnounceOnUdpCausesTransmission
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:123456.0];
    MockEspNetwork* udp = [[MockEspNetwork alloc] init];
    [item announceOnUdp:udp];
    STAssertTrue([udp transmitted],@"announceOnUdp should cause transmission");
}

-(void)testRequestAllOnUdpCausesTransmission
{
    EspCodeShareItem* item = [EspCodeShareItem createWithGridSource:@"name" machine:@"laptop" title:@"grid code" timeStamp:123456.0 length:200];
    MockEspNetwork* udp = [[MockEspNetwork alloc] init];
    [item requestAllOnUdp:udp];
    STAssertTrue([udp transmitted],@"requestAllOnUdp should cause transmission");
}

-(void)testDeliverAllOnUdpCausesTransmission
{
    EspCodeShareItem* item = [EspCodeShareItem createWithLocalContent:@"my code" title:@"local code" timeStamp:123456.0];
    MockEspNetwork* udp = [[MockEspNetwork alloc] init];
    [item deliverAllOnUdp:udp];
    STAssertTrue([udp transmitted],@"deliverAllOnUdp should cause transmission");
}

// -(void) deliverAllOnUdp:(EspNetwork*)udp
// -(void) deliverFragment:(unsigned long)i onUdp:(EspNetwork*)udp



// future tests:
// 2-fragment situation negative
// providing duplicate fragments doesn't mess things up 

@end
