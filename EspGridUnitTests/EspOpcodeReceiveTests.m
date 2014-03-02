//
//  EspOpcodeReceiveTests.m
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

#import "EspOpcodeReceiveTests.h"
#import "EspGridDefs.h"

@implementation MockOpcodeHandler
@synthesize wasHandled;

-(BOOL) handleOpcode:(NSDictionary*)d
{
    [self setWasHandled:YES];
    return YES;
}
@end

@implementation EspOpcodeReceiveTests

-(void) setUp
{
    opcodeReceiver = [[EspInternalProtocol alloc] init];
    opcodeHandler = [[MockOpcodeHandler alloc] init];
    [opcodeReceiver setHandler:opcodeHandler forOpcode:12];
}

-(void) tearDown
{
    [opcodeReceiver release];
    [opcodeHandler release];
}

-(void) testNilDataThrows
{
    STAssertThrows([opcodeReceiver dataReceived:nil fromHost:@"192.168.0.1" atTime:EspGridTime()],
                   @"nil data to dataReceived should throw exception");
}

-(void) testNilHostThrows
{
    NSData* data = [[NSData alloc] init];
    STAssertThrows([opcodeReceiver dataReceived:data fromHost:nil atTime:EspGridTime()],
                   @"nil host to dataReceived should throw exception");
}

-(void) testSettingHandlerBeyondMaximumThrows
{
    EspInternalProtocol* udp = [[EspInternalProtocol alloc] init];
    MockOpcodeHandler* h = [[MockOpcodeHandler alloc] init];
    STAssertThrows([udp setHandler:h forOpcode:300],@"adding opcode handler beyond maximum should throw exception");
}

-(void) testDataWithMatchingOpcodeIsHandled
{
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:12],@"opcode",nil];
    NSError* err;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0 options:0
                                                               error:&err];
    [opcodeReceiver dataReceived:data fromHost:@"192.168.0.1" atTime:EspGridTime()];
    STAssertTrue([opcodeHandler wasHandled],@"data with matching opcode should be handled");
}


-(void) testDataWithMismatchedOpcodeIsNotHandled
{
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:13],@"opcode",nil];
    NSError* err;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0 options:0
                                                               error:&err];
    [opcodeReceiver dataReceived:data fromHost:@"192.168.0.1" atTime:EspGridTime()];
    STAssertFalse([opcodeHandler wasHandled],@"data with mismatching opcode should be handled");
}



@end
