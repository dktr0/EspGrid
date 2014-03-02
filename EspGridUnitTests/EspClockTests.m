//
//  EspClockTests.m
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

#import "EspClockTests.h"
#import "EspGridDefs.h"

@implementation EspClockTests

-(void) setUp
{
    udp = [[MockEspInternalProtocol alloc] init];
    osc = [[EspOsc alloc] init];
    peerList = [[EspPeerList alloc] init];
    clock = [[EspClock alloc] init];
    [clock setOsc:osc];
    [clock setUdp:udp];
    [clock setPeerList:peerList];
    
    beacon = [NSMutableDictionary dictionary];
    [beacon setObject:[NSNumber numberWithInt:ESP_OPCODE_BEACON] forKey:@"opcode"];
    [beacon setObject:@"aName" forKey:@"name"];
    [beacon setObject:@"aMachine" forKey:@"machine"];
    [beacon setObject:@"192.168.2.1" forKey:@"ip"];
    [beacon setObject:[NSNumber numberWithLong:123456] forKey:@"beaconCount"];
    [beacon setObject:[NSNumber numberWithDouble:(EspGridTime())] forKey:@"timeReceived"];
    [beacon setObject:[NSNumber numberWithDouble:(EspGridTime()-0.5)] forKey:@"beaconClock"];
    [beacon setObject:[NSNumber numberWithInt:ESPGRID_MAJORVERSION] forKey:@"majorVersion"];
    [beacon setObject:[NSNumber numberWithInt:ESPGRID_MINORVERSION] forKey:@"minorVersion"];
    [beacon setObject:[NSNumber numberWithInt:2] forKey:@"syncMode"];
    [beacon setObject:[NSNumber numberWithDouble:(EspGridTime()-120.0)] forKey:@"gridClockStart"];
    [beacon setObject:[NSNumber numberWithBool:NO] forKey:@"urgent"];
    
    ack = [NSMutableDictionary dictionary];
    [ack setObject:[NSNumber numberWithInt:ESP_OPCODE_ACK] forKey:@"opcode"];
    [ack setObject:@"bName" forKey:@"name"];
    [ack setObject:@"bMachine" forKey:@"machine"];
    [ack setObject:@"192.168.2.2" forKey:@"ip"];
    [ack setObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"name"] forKey:@"nameRcvd"];
    [ack setObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"] forKey:@"machineRcvd"];
    [ack setObject:@"192.168.2.1" forKey:@"ipRcvd"];
    [ack setObject:[NSNumber numberWithLong:123456] forKey:@"beaconCount"];
    [ack setObject:[NSNumber numberWithDouble:(EspGridTime())] forKey:@"timeReceived"];
    [ack setObject:[NSNumber numberWithDouble:(EspGridTime()-1.0)] forKey:@"beaconReceived"];
    [ack setObject:[NSNumber numberWithDouble:(EspGridTime()-2.0)] forKey:@"beaconClock"];
    [ack setObject:[NSNumber numberWithDouble:(EspGridTime()-3.0)] forKey:@"ackClock"];
    [ack setObject:[NSNumber numberWithDouble:(EspGridTime()-4.0)] forKey:@"clock"];
    [ack setObject:[NSNumber numberWithInt:ESPGRID_MAJORVERSION] forKey:@"majorVersion"];
    [ack setObject:[NSNumber numberWithInt:ESPGRID_MINORVERSION] forKey:@"minorVersion"];

}

-(void) tearDown
{
    [clock release];
    [udp release];
    [osc release];
    [peerList release];
}

-(void) invalidateString:(NSString*)key onOpcode:(NSMutableDictionary*)opcode withMsg:(NSString*)msg
{
    [opcode removeObjectForKey:key];
    STAssertNoThrow([clock handleOpcode:opcode],msg);
    STAssertFalse([clock handleOpcode:opcode],msg);
    [opcode setObject:[NSNumber numberWithInt:666] forKey:key];
    STAssertNoThrow([clock handleOpcode:opcode], msg);
    STAssertFalse([clock handleOpcode:opcode], msg);
    [opcode setObject:@"" forKey:key];
    STAssertNoThrow([clock handleOpcode:opcode], msg);
    STAssertFalse([clock handleOpcode:opcode], msg);
}

-(void) invalidateNumber:(NSString*)key onOpcode:(NSMutableDictionary*)opcode withMsg:(NSString*)msg
{
    [opcode removeObjectForKey:key];
    STAssertNoThrow([clock handleOpcode:opcode], msg);
    STAssertFalse([clock handleOpcode:opcode],msg);
    [opcode setObject:@"oops" forKey:key];
    STAssertNoThrow([clock handleOpcode:opcode],msg);
    STAssertFalse([clock handleOpcode:opcode],msg);
}

-(void) testCompleteBeaconOpcodeIsHandledNoException
{
    STAssertNoThrow([clock handleOpcode:beacon], @"complete BEACON opcode shouldn't throw exception");
    STAssertTrue([clock handleOpcode:beacon],@"complete BEACON opcode should be handled (return TRUE)");
}

-(void) testCompleteAckOpcodeIsHandledNoException
{
    STAssertNoThrow([clock handleOpcode:ack], @"complete ACK opcode shouldn't throw exception");
    STAssertTrue([clock handleOpcode:ack],@"complete ACK opcode should be handled (return TRUE)");
}

-(void) testOpcodeWithInvalidOpcode
{
    [self invalidateNumber:@"opcode" onOpcode:beacon withMsg:@"opcode with invalid opcode shouldn't throw or be handled"];
}

-(void) testBeaconWithInvalidName
{
    [self invalidateString:@"name" onOpcode:beacon withMsg:@"BEACON with invalid name shouldn't throw or be handled"];
}

-(void) testBeaconWithInvalidMachine
{
    [self invalidateString:@"machine" onOpcode:beacon withMsg:@"BEACON with invalid machine shouldn't throw or be handled"];
}

-(void) testBeaconWithInvalidIP
{
    [self invalidateString:@"ip" onOpcode:beacon withMsg:@"BEACON with invalid ip shouldn't throw or be handled"];
}

-(void) testBeaconWithInvalidMajorVersion
{
    [self invalidateNumber:@"majorVersion" onOpcode:beacon withMsg:@"BEACON with invalid majorVersion shouldn't throw or be handled"];
}

-(void) testBeaconWithInvalidMinorVersion
{
    [self invalidateNumber:@"minorVersion" onOpcode:beacon withMsg:@"BEACON with invalid minorVersion shouldn't throw or be handled"];
}

-(void) testAckWithInvalidNameNoHandleNoThrow
{
    [self invalidateString:@"name" onOpcode:ack withMsg:@"ACK opcode with invalid name shouldn't throw or be handled"];
}

-(void) testAckWithInvalidMachineNoHandleNoThrow
{
    [self invalidateString:@"machine" onOpcode:ack withMsg:@"ACK opcode with invalid name shouldn't throw or be handled"];
}

-(void) testAckWithInvalidIPNoHandleNoThrow
{
    [self invalidateString:@"ip" onOpcode:ack withMsg:@"ACK opcode with invalid ip shouldn't throw or be handled"];
}

-(void) testAckWithInvalidNameRcvdNoHandleNoThrow
{
    [self invalidateString:@"nameRcvd" onOpcode:ack withMsg:@"ACK opcode with invalid nameRcvd shouldn't throw or be handled"];
}

-(void) testAckWithInvalidMachineRcvdNoHandleNoThrow
{
    [self invalidateString:@"machineRcvd" onOpcode:ack withMsg:@"ACK opcode with invalid machineRcvd shouldn't throw or be handled"];
}

-(void) testAckWithInvalidIPRcvdNoHandleNoThrow
{
    [self invalidateString:@"ipRcvd" onOpcode:ack withMsg:@"ACK opcode with invalid ipRcvd shouldn't throw or be handled"];
}

-(void) testAckWithInvalidBeaconCount
{
    [self invalidateNumber:@"beaconCount" onOpcode:ack withMsg:@"ACK with invalid beaconCount shouldn't throw or be handled"];
}

-(void) testAckWithInvalidMajorVersion
{
    [self invalidateNumber:@"majorVersion" onOpcode:ack withMsg:@"ACK with invalid majorVersion shouldn't throw or be handled"];
}

-(void) testAckWithInvalidMinorVersion
{
    [self invalidateNumber:@"minorVersion" onOpcode:ack withMsg:@"ACK with invalid minorVersion shouldn't throw or be handled"];
}

-(void) testAckWithInvalidClock
{
    [self invalidateNumber:@"clock" onOpcode:ack withMsg:@"ACK with invalid clock shouldn't throw or be handled"];
}

@end
