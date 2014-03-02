//
//  MockEspInternalProtocol.m
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

#import "MockEspInternalProtocol.h"

@implementation MockEspInternalProtocol
@synthesize transmittedData;
@synthesize burst;
@synthesize transmitted;

-(id) init
{
    self = [super init];
    transmitted = NO;
    return self;
}

-(void) transmitData: (NSData*)data
{
    [self setTransmitted:YES];
    [self setTransmittedData:data];
    [self setBurst:1];
}

-(void) transmitData: (NSData*)data burst:(int)n
{
    [self setTransmitted:YES];
    [self setTransmittedData:data];
    [self setBurst:n];
}

@end
