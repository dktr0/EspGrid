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

+(EspChat*) chat
{
    static EspChat* sharedObject = nil;
    if(!sharedObject)sharedObject = [[EspChat alloc] init];
    return sharedObject;
}

-(id) init
{
    self = [super init];
    network = [EspNetwork network];
    osc = [EspOsc osc];

    // setup CHAT opcode
    chat.header.opcode = ESP_OPCODE_CHATSEND;
    chat.header.length = sizeof(EspChatOpcode);
    copyNameAndMachineIntoOpcode((EspOpcode*)&chat);

    return self;
}


-(void) sendMessage:(NSString*)msg
{
    // transmit opcode in internal protocol
    const char* msgCString = [msg cStringUsingEncoding:NSUTF8StringEncoding];
    strncpy(chat.text, msgCString, ESP_CHAT_MAXLENGTH);
    chat.text[ESP_CHAT_MAXLENGTH-1] = 0;
    copyNameAndMachineIntoOpcode((EspOpcode*)&chat); // to fix: really should only be when defaults change...
    [network sendOpcode:(EspOpcode*)&chat];

    // send to subscribers to external protocol
    NSString* from = [[NSUserDefaults standardUserDefaults] stringForKey:@"person"];
    NSArray* a = [NSArray arrayWithObjects:@"/esp/chat/receive",from,msg,nil];
    [osc transmit:a log:YES];

    // post chat message in this process
    NSString* m = [NSString stringWithFormat:@"%@: %@",from,msg];
    postChat(m);
}

-(void) handleOpcode:(EspOpcode *)opcode
{
    NSAssert(opcode->opcode == ESP_OPCODE_CHATSEND,@"EspChat sent unrecognized opcode");
    EspChatOpcode* msgRcvd = (EspChatOpcode*)opcode;

    // sanitize strings
    msgRcvd->text[ESP_CHAT_MAXLENGTH-1] = 0;
    opcode->name[15] = 0;

    // post message in this process
    postChat([NSString stringWithFormat:@"%s: %s",opcode->name,msgRcvd->text]);

    // and send it to all external protocol subscribers
    NSString* x = [NSString stringWithCString:opcode->name encoding:NSUTF8StringEncoding];
    NSString* y = [NSString stringWithCString:msgRcvd->text encoding:NSUTF8StringEncoding];
    NSArray* a = [NSArray arrayWithObjects:@"/esp/chat/receive",x,y,nil];
    [osc transmit:a log:YES];
}

-(void) handleOldOpcode:(NSDictionary*)d;
{
    NSAssert(false,@"empty old opcode handler in EspChat called");
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    if([address isEqual:@"/esp/chat/send"])
    {
        if([d count]<1){postProblem(@"received /esp/chat/send with no parameters",self); return NO;}
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
