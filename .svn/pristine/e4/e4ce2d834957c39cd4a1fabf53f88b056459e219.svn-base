//
//  EspCodeShareTests.m
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

#import "EspCodeShareTests.h"
#import "EspCodeShare.h"
#import "EspGridDefs.h"

@interface MockEspClock : EspClock
-(EspTimeType)adjusted;
@end

@implementation MockEspClock
-(EspTimeType)adjusted
{
    return EspGridTime();
}
@end

@implementation EspCodeShareTests

- (void)setUp
{
    [super setUp];
    clock = [[MockEspClock alloc] init];
    codeShare = [[EspCodeShare alloc] init];
    [codeShare setClock:clock];
    validAnnounce = [NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithInt:ESP_OPCODE_ANNOUNCESHARE],@"opcode",
                     @"max",@"sourceName",
                     @"PDP11",@"sourceMachine",
                     @"max",@"name",
                     @"PDP11",@"machine",
                     @"10.0.0.10",@"ip",
                     @"title by max",@"title",
                     [NSNumber numberWithLong:200],@"length",
                     [NSNumber numberWithDouble:123456.0],@"timeStamp", nil];
}

- (void)tearDown
{
    codeShare = nil;
    validAnnounce = nil;
    [super tearDown];
}

-(void)testCountOfSharesStartsAtZero
{
    STAssertTrue([codeShare countOfShares]==0, @"A new EspCodeShare should have no items in it.");
}

-(void)testSharingLocalTextIncreasesCountOfShares
{
    // codeShare needs a connection to a mock clock for this to work...
    [codeShare shareCode:@"this is some text to share" withTitle:@"title"];
    STAssertTrue([codeShare countOfShares]==1, @"Sharing local text should increase count of shares.");
}

-(void)testSharingLocalTextIsCompleteAndMatches
{
    [codeShare shareCode:@"this is some text to share" withTitle:@"title"];
    STAssertTrue([[[codeShare items] objectAtIndex:0] complete],@"sharing local text should be complete");
    NSString* content = [[[codeShare items] objectAtIndex:0] content];
    STAssertTrue(content != nil, @"sharing local text should lead to non nil content");
    STAssertTrue([content isKindOfClass:[NSString class]], @"sharing local text should lead to NSString content");
    STAssertTrue([content isEqualToString:@"this is some text to share"], @"sharing local text should lead to matching content");
}


-(void)testCodeShareSaysItCanHandleAnnounceOpcode
{
    STAssertTrue([codeShare handleOpcode:validAnnounce]==YES, @"EspCodeShare should return YES for ANNOUNCESHARE opcode");
}

-(void)testReceivingAnnouncementIncreasesCountOfShares
{
    [codeShare handleOpcode:validAnnounce];
    STAssertTrue([codeShare countOfShares]==1, @"Receiving a valid announce opcode should increase count of shares.");
}

-(void)testReceivingDuplicateAnnouncementDoesntIncreaseCountOfShares
{
    [codeShare handleOpcode:validAnnounce];
    [codeShare handleOpcode:validAnnounce];
    STAssertTrue([codeShare countOfShares]==1, @"Receiving a duplicate valid announce opcode should only increase count of shares by one.");
}

-(void)testReceivingAnnounceWithInvalidNameDoesntIncreaseCountOfShares
{
    NSMutableDictionary* noName = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noName removeObjectForKey:@"sourceName"];
    [codeShare handleOpcode:noName];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with nil sourceName shouldn't increase count of shares");
    
    noName = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noName setObject:[NSNumber numberWithInt:42] forKey:@"sourceName"];
    [codeShare handleOpcode:noName];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with sourceName of wrong type shouldn't increase count of shares");
    
    noName = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noName setObject:@"" forKey:@"sourceName"];
    [codeShare handleOpcode:noName];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with sourceName of length zero shouldn't increase count of shares");
}

-(void)testReceivingAnnounceWithInvalidMachineDoesntIncreaseCountOfShares
{
    NSMutableDictionary* noMachine = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noMachine removeObjectForKey:@"sourceMachine"];
    [codeShare handleOpcode:noMachine];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with nil sourceMachine shouldn't increase count of shares");
    
    noMachine = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noMachine setObject:[NSNumber numberWithInt:42] forKey:@"sourceMachine"];
    [codeShare handleOpcode:noMachine];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with sourceMachine of wrong type shouldn't increase count of shares");

    noMachine = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noMachine setObject:@"" forKey:@"sourceMachine"];
    [codeShare handleOpcode:noMachine];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with sourceMachine of length zero shouldn't increase count of shares");
}

-(void)testReceivingAnnounceWithInvalidTitleDoesntIncreaseCountOfShares
{
    NSMutableDictionary* noTitle = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noTitle removeObjectForKey:@"title"];
    [codeShare handleOpcode:noTitle];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with nil title shouldn't increase count of shares");

    noTitle = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noTitle setObject:[NSNumber numberWithInt:42] forKey:@"title"];
    [codeShare handleOpcode:noTitle];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with title of wrong type shouldn't increase count of shares");

    noTitle = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noTitle setObject:@"" forKey:@"title"];
    [codeShare handleOpcode:noTitle];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with title of length zero shouldn't increase count of shares");
}

-(void)testReceivingAnnounceWithInvalidTimeStampDoesntIncreaseCountOfShares
{
    NSMutableDictionary* noTimeStamp = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noTimeStamp removeObjectForKey:@"timeStamp"];
    [codeShare handleOpcode:noTimeStamp];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with nil timeStamp shouldn't increase count of shares");

    noTimeStamp = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noTimeStamp setObject:@"aString" forKey:@"timeStamp"];
    [codeShare handleOpcode:noTimeStamp];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with timeStamp not NSNumber shouldn't increase count of shares");
}

-(void)testReceivingAnnounceWithInvalidLengthDoesntIncreaseCountOfShares
{
    NSMutableDictionary* noLength = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noLength removeObjectForKey:@"length"];
    [codeShare handleOpcode:noLength];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with nil length shouldn't increase count of shares");
    
    noLength = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noLength setObject:@"aString" forKey:@"length"];
    [codeShare handleOpcode:noLength];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with length not NSNumber shouldn't increase count of shares");
    
    noLength = [NSMutableDictionary dictionaryWithDictionary:validAnnounce];
    [noLength setObject:[NSNumber numberWithLong:0] forKey:@"length"];
    [codeShare handleOpcode:noLength];
    STAssertTrue([codeShare countOfShares]==0, @"Announcement with length <=0 shouldn't increase count of shares");
}

-(void)testReceivingValidAnnounceAndFragmentsIsCompleteAndCorrect
{
    const unichar c1 = '1';
    const unichar c2 = '2';
    NSString* fragment1code = [NSString stringWithCharacters:&c1 length:128];
    NSString* fragment2code = [NSString stringWithCharacters:&c2 length:72];
    NSString* validResult = [NSString stringWithFormat:@"%@%@",fragment1code,fragment2code];
    NSDictionary* fragment1 = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithInt:ESP_OPCODE_DELIVERSHARE],@"opcode",
                               @"max",@"sourceName",@"PDP11",@"sourceMachine",@"10.0.0.10",@"ip",fragment1code,@"fragment",
                               [NSNumber numberWithLong:0],@"index",[NSNumber numberWithDouble:123456.0],@"timeStamp", nil];
    NSDictionary* fragment2 = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithInt:ESP_OPCODE_DELIVERSHARE],@"opcode",
                               @"max",@"sourceName",@"PDP11",@"sourceMachine",@"10.0.0.10",@"ip",fragment2code,@"fragment",
                               [NSNumber numberWithLong:1],@"index",[NSNumber numberWithDouble:123456.0],@"timeStamp", nil];
    [codeShare handleOpcode:validAnnounce];
    [codeShare handleOpcode:fragment1];
    [codeShare handleOpcode:fragment2];
    STAssertTrue([[[codeShare items] objectAtIndex:0] complete]==YES,@"valid announce and fragments should be complete");
    NSString* content = [[[codeShare items] objectAtIndex:0] content];
    STAssertTrue(content != nil,@"valid announce and fragments should lead to non nil content");
    STAssertTrue([content isKindOfClass:[NSString class]],@"valid announce and fragments should lead to NSString content");
    STAssertTrue([content isEqualToString:validResult],@"valid announce+fragments should lead to reconstructed content");
}

@end
