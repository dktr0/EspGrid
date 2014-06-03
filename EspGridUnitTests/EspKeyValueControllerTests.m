//
//  EspKeyValueControllerTests.m
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

#import "EspKeyValueControllerTests.h"
#import "EspGridDefs.h"

@implementation EspKeyValueControllerTests

-(void) setUp
{
    udp = [[MockEspNetwork alloc] init];
    osc = [[EspOsc alloc] init];
    peerList = [[EspPeerList alloc] init];
    clock = [[EspClock alloc] init];
    [clock setPeerList:peerList];
    [clock setUdp:udp];
    [clock setOsc:osc];
    model = [NSMutableDictionary dictionary];
    kvc = [[EspKeyValueController alloc] init];
    [kvc setUdp:udp];
    [kvc setOsc:osc];
    [kvc setClock:clock];
    [kvc setModel:model];
    [kvc addKeyPath:@"myKeyPath"];

    kvcop = [NSMutableDictionary dictionary];
    [kvcop setObject:[NSNumber numberWithInt:ESP_OPCODE_KVC] forKey:@"opcode"];
    [kvcop setObject:@"aName" forKey:@"name"];
    [kvcop setObject:@"aMachine" forKey:@"machine"];
    [kvcop setObject:@"192.168.2.1" forKey:@"ip"];
    
    [kvcop setObject:@"myKeyPath" forKey:@"keyPath"];
    [kvcop setObject:@"this is a value" forKey:@"value"];
    [kvcop setObject:[NSNumber numberWithDouble:123456.0] forKey:@"time"];
}

-(void) tearDown
{
    [kvc release];
    [clock release];
    [peerList release];
    [osc release];
    [udp release];
}

-(void) invalidateString:(NSString*)key onOpcode:(NSMutableDictionary*)opcode withMsg:(NSString*)msg
{
    [opcode removeObjectForKey:key];
    STAssertNoThrow([kvc handleOpcode:opcode],msg);
    STAssertFalse([kvc handleOpcode:opcode],msg);
    [opcode setObject:[NSNumber numberWithInt:666] forKey:key];
    STAssertNoThrow([kvc handleOpcode:opcode], msg);
    STAssertFalse([kvc handleOpcode:opcode], msg);
    [opcode setObject:@"" forKey:key];
    STAssertNoThrow([kvc handleOpcode:opcode], msg);
    STAssertFalse([kvc handleOpcode:opcode], msg);
}

-(void) invalidateNumber:(NSString*)key onOpcode:(NSMutableDictionary*)opcode withMsg:(NSString*)msg
{
    [opcode removeObjectForKey:key];
    STAssertNoThrow([kvc handleOpcode:opcode], msg);
    STAssertFalse([kvc handleOpcode:opcode],msg);
    [opcode setObject:@"oops" forKey:key];
    STAssertNoThrow([kvc handleOpcode:opcode],msg);
    STAssertFalse([kvc handleOpcode:opcode],msg);
}

-(void) testCompleteKvcOpcodeWorks
{
    STAssertNoThrow([kvc handleOpcode:kvcop], @"complete KVC opcode shouldn't throw exception");
    STAssertTrue([kvc handleOpcode:kvcop],@"complete KVC opcode should be handled (return TRUE)");
    STAssertTrue([[model objectForKey:@"myKeyPath"] isEqualToString:@"this is a value"],@"complete KVC opcode should change model value");
}

-(void) testInvalidOpcode
{
    [self invalidateNumber:@"opcode" onOpcode:kvcop withMsg:@"opcode with invalid opcode field should not throw or be handled"];
}

-(void) testInvalidKeyPath
{
    [self invalidateString:@"keyPath" onOpcode:kvcop withMsg:@"KVC with invalid keyPath field should not throw or be handled"];
}

-(void) testInvalidValue
{
    [kvcop removeObjectForKey:@"value"];
    STAssertNoThrow([kvc handleOpcode:kvcop], @"KVC with missing 'value' should not throw");
    STAssertFalse([kvc handleOpcode:kvcop], @"KVC with missing 'value' should not be handled");
}

-(void) testInvalidTime
{
    [self invalidateNumber:@"time" onOpcode:kvcop withMsg:@"KVC with invalid time should not throw or be handled"];
}

@end
