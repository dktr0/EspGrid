//
//  main.m
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

#import <Foundation/Foundation.h>
#import "EspGrid.h"

int main(int argc, const char * argv[])
{
    NSLog(@"espgridd (-h for help)");
    if(argc == 2 && (!strcmp(argv[1],"-h") || !strcmp(argv[1],"--help")))
    {
        NSLog(@" --help (gets help, run without this in order to launch grid)");
        NSLog(@" --name [name] (sets performer name on grid, only needed when changing)");
        NSLog(@" --machine [name] (sets machine name on grid, only needed when changing)");
        NSLog(@" --broadcast [address] [(sets LAN broadcast address, only needed when changing)");
        NSLog(@" --connectToMax [1 or 0]");
        NSLog(@" --connectToChuck [1 or 0]");
        NSLog(@" --connectToPD [1 or 0]");
        NSLog(@" --connectToSupercollider [1 or 0]");
        NSLog(@" --clockMode [value] (sets clock mode, possible values: 0 1 2)");
    }
    else
    {
        NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
        EspGrid* grid = [[EspGrid alloc] init];
        [[NSRunLoop currentRunLoop] run];
        [grid release];
        [pool drain];
    }
    return 0;
}

