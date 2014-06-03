//
//  EspChatTests.m
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

#import "EspChatTests.h"
#import "EspChat.h"
#import "EspGridDefs.h"

@implementation EspChatTests

-(void) setUp
{
    udp = [[MockEspNetwork alloc] init];
    osc = [[EspOsc alloc] init];
    chat = [[EspChat alloc] init];
    [chat setOsc:osc];
    [chat setUdp:udp];
    chatopc = [NSMutableDictionary dictionary];
    [chatopc setObject:[NSNumber numberWithInt:ESP_OPCODE_CHATSEND] forKey:@"opcode"];
    [chatopc setObject:@"aName" forKey:@"name"];
    [chatopc setObject:@"this is a chat message" forKey:@"msg"];
}

-(void) tearDown
{
    [chat release];
    [udp release];
    [osc release];
}

-(void) invalidateString:(NSString*)key onOpcode:(NSMutableDictionary*)opcode withMsg:(NSString*)msg
{
    [opcode removeObjectForKey:key];
    STAssertNoThrow([chat handleOpcode:opcode],msg);
    STAssertFalse([chat handleOpcode:opcode],msg);
    [opcode setObject:[NSNumber numberWithInt:666] forKey:key];
    STAssertNoThrow([chat handleOpcode:opcode], msg);
    STAssertFalse([chat handleOpcode:opcode], msg);
    [opcode setObject:@"" forKey:key];
    STAssertNoThrow([chat handleOpcode:opcode], msg);
    STAssertFalse([chat handleOpcode:opcode], msg);
}

-(void) invalidateNumber:(NSString*)key onOpcode:(NSMutableDictionary*)opcode withMsg:(NSString*)msg
{
    [opcode removeObjectForKey:key];
    STAssertNoThrow([chat handleOpcode:opcode], msg);
    STAssertFalse([chat handleOpcode:opcode],msg);
    [opcode setObject:@"oops" forKey:key];
    STAssertNoThrow([chat handleOpcode:opcode],msg);
    STAssertFalse([chat handleOpcode:opcode],msg);
}

-(void) testCompleteChatOpcodeDoesntThrow
{
    STAssertNoThrow([chat handleOpcode:chatopc], @"complete chat opcode shouldn't throw exception");
}

-(void) testInvalidOpcode
{
    [self invalidateNumber:@"opcode" onOpcode:chatopc withMsg:@"opcode missing opcode field shouldn't throw or be handled"];
}

-(void) testInvalidName
{
    [self invalidateString:@"name" onOpcode:chatopc withMsg:@"CHAT with invalid name shouldn't throw or be handled"];
}

-(void) testInvalidMsg
{
    [self invalidateString:@"msg" onOpcode:chatopc withMsg:@"CHAT with invalid msg shouldn't throw or be handled"];
}

@end
