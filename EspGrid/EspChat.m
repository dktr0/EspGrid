//
//  EspChat.m
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

#import "EspChat.h"
#import "EspGridDefs.h"

@implementation EspChat
@synthesize udp;
@synthesize osc;

-(void) sendMessage:(NSString*)msg
{
    NSDictionary* d = [NSDictionary dictionaryWithObject:msg forKey:@"msg"];
    [udp transmitOpcode:ESP_OPCODE_CHATSEND withDictionary:d burst:64];
    NSString* from = [[NSUserDefaults standardUserDefaults] stringForKey:@"name"];
    NSArray* a = [NSArray arrayWithObjects:@"/esp/chat/receive",from,msg,nil];
    [osc transmit:a log:YES];
    NSString* m = [NSString stringWithFormat:@"%@: %@",from,msg];
    postChat(m);
}

-(BOOL) handleOpcode:(NSDictionary*)d;
{
    int opcode = [[d objectForKey:@"opcode"] intValue];
    
    if(opcode==ESP_OPCODE_CHATSEND) {
        NSString* name = [d objectForKey:@"name"]; VALIDATE_OPCODE_NSSTRING(name);
        NSString* msg = [d objectForKey:@"msg"]; VALIDATE_OPCODE_NSSTRING(msg);
        NSString* msgOut = [NSString stringWithFormat:@"%@: %@",name,msg];
        postChat(msgOut); // post received message in-app
        // and send it to all registered OSC clients
        NSArray* a = [NSArray arrayWithObjects:@"/esp/chat/receive",name,msg,nil];
        [osc transmit:a log:YES];
        return YES;
    }
    return NO;
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    if([address isEqual:@"/esp/chat/send"])
    {
        if([d count]<1){postProblem(@"received /esp/chat/send with no parameters",self); return NO;}
        else [osc logReceivedMessage:address fromHost:h port:p];
        NSMutableString* msg = [[NSMutableString alloc] init];
        for(int i=0;i<[d count];i++)
        {
            [msg appendFormat:@"%@ ",[d objectAtIndex:i]];
        }
        [self sendMessage:msg];
        return YES;
    }
    return NO;
}

@end
