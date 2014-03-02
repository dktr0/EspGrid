//
//  EspOscTests.m
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

#import "EspOscTests.h"

@implementation MockEspOscHandler
@synthesize address;
@synthesize parameters;
@synthesize handled;
-(id)init
{
    self = [super init];
    handled = FALSE;
    return self;
}

-(BOOL) handleOsc:(NSString*)a withParameters:(NSArray*)d
{
    [self setAddress:a];
    [self setParameters:d];
    [self setHandled:TRUE];
    return YES;
}

@end

@implementation EspOscTests

- (void)setUp
{
    [super setUp];
    oscReceive = [[EspOsc alloc] init];
    handler = [[MockEspOscHandler alloc] init];
    [oscReceive addHandler:handler forAddress:@"/esp/osc/test"];
}

- (void)tearDown
{
    [oscReceive release];
    [handler release];
    [super tearDown];
}

-(void)testMatchedAddressIsHandled
{
    char* msg = "/esp/osc/test\0\0\0,\0\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:20 freeWhenDone:NO];
    [oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()];
    STAssertTrue([handler handled],@"Matched OSC address should be handled.");
}
                  
-(void)testMismatchedAddressIsNotHandled
{
    char* msg = "/esp/osc/no!!\0\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:16 freeWhenDone:NO];
    [oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()];
    STAssertFalse([handler handled],@"Mismatched OSC address should not be handled.");
}

-(void)testNilDataThrowsException
{
    STAssertThrows([oscReceive dataReceived:nil fromHost:@"127.0.0.1" atTime:EspGridTime()],
                   @"nil data to oscReceive should throw exception.");
}

-(void)testZeroLengthDataThrowsException
{
    char* msg = "\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:0 freeWhenDone:NO];
    STAssertThrows([oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()],
                   @"zero length data to oscReceive should throw exception.");
}

-(void)testMalformedAddressIsNotHandledWithoutException
{
    char* msg = "\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:2 freeWhenDone:NO];
    STAssertNoThrow([oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()],
                    @"malformed address should not throw exception");
    STAssertFalse([handler handled],@"malformed address should not be handled");
}

-(void)testMissingIntParameterIsNotHandledWithoutException
{
    char* msg = "/esp/osc/test\0\0\0,i\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:20 freeWhenDone:NO];
    STAssertNoThrow([oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()],
                    @"message missing int parameter should not throw exception");
    STAssertFalse([handler handled],@"message missing int parameter should not be handled");
}

-(void)testSingleIntParameterIsReceived
{
    char* msg = "/esp/osc/test\0\0\0,i\0\0\0\0\0\1";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:24 freeWhenDone:NO];
    [oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()];
    STAssertTrue([[handler parameters] count]==1,@"receiving a single int by OSC should lead to 1 parameter");
    STAssertTrue([[[handler parameters] objectAtIndex:0] isKindOfClass:[NSNumber class]],
                  @"single int from OSC should be parsed as NSNumber");
    STAssertTrue([[[handler parameters] objectAtIndex:0] isEqualTo:[NSNumber numberWithInt:1]],
                 @"single int from OSC should have been equal to 1");
}

-(void)testMissingFloatParameterIsNotHandledWithoutException
{
    char* msg = "/esp/osc/test\0\0\0,f\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:20 freeWhenDone:NO];
    STAssertNoThrow([oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()],
                    @"message missing float parameter should not throw exception");
    STAssertFalse([handler handled],@"message missing float parameter should not be handled");
}

-(void)testSingleFloatParameterIsReceived
{
    char* msg = "/esp/osc/test\0\0\0,f\0\0\0\0\0\1";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:24 freeWhenDone:NO];
    [oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()];
    STAssertTrue([[handler parameters] count]==1,@"receiving a single float by OSC should lead to 1 parameter");
    STAssertTrue([[[handler parameters] objectAtIndex:0] isKindOfClass:[NSNumber class]],
                 @"single float from OSC should be parsed as NSNumber");
}

-(void)testMissingStringParameterIsNotHandledWithoutException
{
    char* msg = "/esp/osc/test\0\0\0,s\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:20 freeWhenDone:NO];
    STAssertNoThrow([oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()],
                    @"message missing string parameter should not throw exception");
    STAssertFalse([handler handled],@"message missing string parameter should not be handled");
}

-(void)testSingleStringParameterIsReceived
{
    char* msg = "/esp/osc/test\0\0\0,s\0\0test\0\0\0\0";
    NSData* d = [NSData dataWithBytesNoCopy:msg length:28 freeWhenDone:NO];
    [oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()];
    STAssertTrue([[handler parameters] count]==1,@"receiving a single string by OSC should lead to 1 parameter");
    STAssertTrue([[[handler parameters] objectAtIndex:0] isKindOfClass:[NSString class]],
                 @"single string from OSC should be parsed as NSString");
    STAssertTrue([[[handler parameters] objectAtIndex:0] isEqualTo:@"test"],
                 @"single string from OSC should have been equal to 'test'");
}

-(void)testUnterminatedSingleStringParameterIsNotHandled
{
    char* msg = "/esp/osc/test\0\0\0,s\0\0test!!!!"; // !!!! added to "unterminate" string
    NSData* d = [NSData dataWithBytesNoCopy:msg length:24 freeWhenDone:NO];
    [oscReceive dataReceived:d fromHost:@"127.0.0.1" atTime:EspGridTime()];
    STAssertFalse([handler handled],@"receiving unterminated string by OSC should be unhandled");
}

@end
