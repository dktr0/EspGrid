//
//  EspInternalProtocol.m
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

#import "EspInternalProtocol.h"
#import "EspGridDefs.h"

@implementation EspInternalProtocol
@synthesize peerList;
@synthesize bridge;

char* opcodeName[ESP_NUMBER_OF_OPCODES];

+(void) initialize
{
    opcodeName[ESP_OPCODE_BEACON] = "BEACON";
    opcodeName[ESP_OPCODE_ACK] = "ACK";
    opcodeName[ESP_OPCODE_CHATSEND] = "CHATSEND";
    opcodeName[ESP_OPCODE_KVC] = "KVC";
    opcodeName[ESP_OPCODE_ANNOUNCESHARE] = "ANNOUNCESHARE";
    opcodeName[ESP_OPCODE_REQUESTSHARE]="REQUESTSHARE";
    opcodeName[ESP_OPCODE_DELIVERSHARE]="DELIVERSHARE";
    opcodeName[ESP_OPCODE_OSCNOW]="OSCNOW";
    opcodeName[ESP_OPCODE_OSCFUTURE]="OSCFUTURE";
}

-(id) init
{
    self = [super init];
    udpReceive = [[EspSocket alloc] initWithPort:5509 andDelegate:self];
    hashQueue = [[NSMutableArray alloc] init];
    for(int x=0;x<100;x++)[hashQueue addObject:[NSNull null]];
    return self;
}

-(void) dealloc
{
    [udpReceive release];
    [hashQueue release];
    [super dealloc];
}

-(void) setHandler:(id)h forOpcode:(int)o
{
    NSAssert(o < ESPUDP_MAX_HANDLERS, @"attempt to add opcode handler beyond maximum");
    handlers[o] = h; 
}

-(void) transmitOpcode:(int)opcode withDictionary:(NSDictionary*)d burst:(int)n
{
    @try
    {
        // add opcode, name, machine and hash (to filter duplicate messages) to dictionary
        NSMutableDictionary* e = [NSMutableDictionary dictionaryWithDictionary:d];
        [e setValue:[NSNumber numberWithInt:opcode] forKey:@"opcode"];
        [e setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"name"] forKey:@"name"];
        [e setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"machine"] forKey:@"machine"];
        [e setValue:[NSNumber numberWithLong:messageHash] forKey:@"hash"];
        messageHash++;
    
        // prepare dictionary as data for transmission
        NSError* err = nil;
        NSData* data = [NSPropertyListSerialization dataWithPropertyList:e
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0
                                                                   error:&err];
        if(err != nil) {
            NSString* log = [NSString stringWithFormat:@"unable to serialize property list for %s(%d)",
                             opcodeName[opcode],opcode];
            postProblem(log, nil);
        } else {
            NSString* log = [NSString stringWithFormat:@"sending %s(%d) with %ld bytes",
                             opcodeName[opcode],opcode,[data length]];
            postLog(log, nil);
            for(int x=0;x<n;x++) {
                [udpReceive sendDataWithTimes:data
                              toHost:[[NSUserDefaults standardUserDefaults] stringForKey:@"broadcast"]];
            }
            [bridge transmitOpcode:d]; // note: burst behaviour not continued over bridge for now
        }
    }
    @catch (NSException* exception)
    {
        NSString* msg = [NSString stringWithFormat:@"EXCEPTION in transmitOpcode: %@: %@",[exception name],[exception reason]];
        postProblem(msg, self);
        @throw;
    }
}

- (void)dataReceived:(NSData*)d fromHost:(NSString*)h fromPort:(int)p systemTime:(EspTimeType)timestamp monotonicTime:(EspTimeType)monotonic;
{
    @try {
        NSAssert(d != nil, @"data should not be nil");
        NSAssert(h != nil, @"host should not be nil");
        NSError* err = nil;
        
        EspTimeType monotonicSendTime = *((EspTimeType*)[d bytes]); // first 8 bytes are monotonic send time
        EspTimeType systemSendTime = *((EspTimeType*)([d bytes]+8)); // next 8 are system send time
        NSData* temp = [NSData dataWithBytesNoCopy:[d bytes]+16 length:[d length]-16 freeWhenDone:NO];
        
        NSMutableDictionary* plist =
        (NSMutableDictionary*)[NSPropertyListSerialization propertyListWithData:temp
                                                                    options:NSPropertyListMutableContainers format:NULL error:&err];
        if(plist != nil)
        {
            [plist setValue:[NSNumber numberWithLongLong:timestamp] forKey:@"timeReceived"];
            [plist setValue:h forKey:@"ip"];
            [plist setValue:[NSNumber numberWithInt:p] forKey:@"port"];
            [plist setValue:[NSNumber numberWithLongLong:monotonicSendTime] forKey:@"monotonicSendTime"];
            [plist setValue:[NSNumber numberWithLongLong:systemSendTime] forKey:@"systemSendTime"];
            [plist setValue:[NSNumber numberWithLongLong:monotonic] forKey:@"monotonicReceiveTime"];
            [plist setValue:[NSNumber numberWithLongLong:timestamp] forKey:@"systemReceiveTime"];
            [self receivedOpcode:plist];
        }
        else
        {
            NSString* s = [NSString stringWithFormat:@"unable to deserialize packet of length %lu into property list (opcode)",[d length]];
            postProblem(s, self);
        }
    }
    @catch (NSException* exception) {
        NSString* msg = [NSString stringWithFormat:@"EXCEPTION in dataReceived: %@: %@",[exception name],[exception reason]];
        postProblem(msg, self);
        @throw;
    }
}

-(void) transmitOpcodeToSelf:(int)opcode withDictionary:(NSDictionary*)d
{
    NSMutableDictionary* d2 = [NSMutableDictionary dictionaryWithDictionary:d];
    [d2 setValue:[NSNumber numberWithInt:opcode] forKey:@"opcode"];
    [self handleOpcode:d2];
}

-(void) receivedOpcode: (NSDictionary*)d
{

    BOOL goAhead = NO;
    id hash = [d objectForKey:@"hash"];
    if(!hash) goAhead = YES; // process opcode if hash key not found in rcvd message...
    else if(![self isDuplicateMessage:d]) goAhead = YES; // ...or if not duplicate hash
    
    if(goAhead == YES) {
        if([[d objectForKey:@"name"] isEqual:[[NSUserDefaults standardUserDefaults] stringForKey:@"name"]]) {
            if([[d objectForKey:@"machine"] isEqual:[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"]])
            { // name and machine are our own - so don't process message
            goAhead = NO;
            }
        }
        else if([d objectForKey:@"bridgeName"] != nil && [d objectForKey:@"bridgeMachine"] != nil)
        {   
            if([[d objectForKey:@"bridgeName"] isEqual:[[NSUserDefaults standardUserDefaults] stringForKey:@"name"]]) {
                if([[d objectForKey:@"bridgeMachine"] isEqual:[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"]])
                { // since bridgeName and machine match our name this is is a packet rebroadcast by us from a bridge, so ignore
                    goAhead = NO; 
                }
            }
        }
    } // else NSLog(@"duplicate message");
    
    if(goAhead)
    {
        [self handleOpcode:d];
        [bridge retransmitOpcode:d];
    }

}

-(BOOL) handleOpcode: (NSDictionary*)d
{
    int opcode = [[d objectForKey:@"opcode"] intValue];
    id<EspHandleOpcode> h = handlers[opcode];
    if(h == nil) {
        NSString* s = [NSString stringWithFormat:@"no handler for opcode %d from %@-%@ at %@",opcode,[d objectForKey:@"name"],[d objectForKey:@"machine"],[d objectForKey:@"ip"]];
        postProblem(s,self);
    }
    NSString* log = [NSString stringWithFormat:@"received %s(%d) from %@-%@ at %@ with %ld entries",
                     opcodeName[opcode],
                     opcode,
                     [d objectForKey:@"name"],
                     [d objectForKey:@"machine"],
                     [d objectForKey:@"ip"],
                     [d count]];
    postLog(log, nil);
    return [h handleOpcode:d];
}

-(BOOL) isDuplicateMessage: (NSDictionary*)msg
{
    NSString* h = [NSString stringWithFormat:@"%@-%@-%@",
                    [msg objectForKey:@"hash"],
                    [msg objectForKey:@"name"],
                   [msg objectForKey:@"machine"]];
    if([hashQueue containsObject:h]){
        return YES;   
    } 
    else {
        [hashQueue replaceObjectAtIndex:hashQueueIndex withObject:h];
        hashQueueIndex++;
        if(hashQueueIndex >= 100) hashQueueIndex = 0;
        return NO;       
    }
}


@end
