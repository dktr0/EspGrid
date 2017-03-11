//
//  EspNetwork.m
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

#import "EspNetwork.h"
#import "EspGridDefs.h"

@implementation EspNetwork
@synthesize broadcast, bridge;

char* opcodeName[ESP_NUMBER_OF_OPCODES];

+(void) initialize
{
    opcodeName[ESP_OPCODE_BEACON] = "BEACON";
    opcodeName[ESP_OPCODE_ACK] = "ACK";
    opcodeName[ESP_OPCODE_PEERINFO] = "PEERINFO";
    opcodeName[ESP_OPCODE_CHATSEND] = "CHATSEND";
    opcodeName[ESP_OPCODE_KVC] = "KVC";
    opcodeName[ESP_OPCODE_ANNOUNCESHARE] = "ANNOUNCESHARE";
    opcodeName[ESP_OPCODE_REQUESTSHARE]="REQUESTSHARE";
    opcodeName[ESP_OPCODE_DELIVERSHARE]="DELIVERSHARE";
    opcodeName[ESP_OPCODE_OSCNOW]="OSCNOW";
    opcodeName[ESP_OPCODE_OSCFUTURE]="OSCFUTURE";
}

+(EspNetwork*) network
{
    static EspNetwork* theSharedObject = nil;
    if(!theSharedObject) theSharedObject = [[super alloc] init];
    return theSharedObject;
}

-(id) init
{
    self = [super init];
    if(self)
    {
        channels = [[NSMutableArray alloc] init];
        broadcast = [[EspChannel alloc] init];
        [broadcast setDelegate:self];
        [broadcast setPort:5509];
        [broadcast setHost:[[NSUserDefaults standardUserDefaults] objectForKey:@"broadcast"]];
        [channels addObject:broadcast];
        bridge = [[EspChannel alloc] init];
        [bridge setDelegate:self];
    }
    return self;
}


-(void) dealloc
{
    [channels release];
    [super dealloc];
}

-(void) broadcastAddressChanged
{
    [broadcast setHost:[[NSUserDefaults standardUserDefaults] objectForKey:@"broadcast"]];
}

-(void) sendOldOpcode:(unsigned int)opcode withDictionary:(NSDictionary*)d
{
    @try
    {
        NSString* log = [NSString stringWithFormat:@"sending (old) opcode %s(%d)",opcodeName[opcode],opcode];
        postLog(log, nil);
        NSMutableDictionary* e = [NSMutableDictionary dictionaryWithDictionary:d];
        [e setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"person"] forKey:@"name"];
        [e setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"machine"] forKey:@"machine"];
        for(EspChannel* c in channels) [c sendOldOpcode:opcode withDictionary:e]; // send on all channels
    }
    @catch (NSException* exception)
    {
        NSString* msg = [NSString stringWithFormat:@"EXCEPTION sending %s(%d): %@: %@",
                         opcodeName[opcode],opcode,[exception name],[exception reason]];
        postProblem(msg, self);
        @throw;
    }
}

-(void) sendOpcode:(EspOpcode*)opcode
{
    NSString* log = [NSString stringWithFormat:@"sending opcode %s(%d)",opcodeName[opcode->opcode],opcode->opcode];
    postLog(log, nil);
    for(EspChannel* c in channels) [c sendOpcode:opcode]; // send on all channels
}

// ***REMEMBER: need to make sure preferences change to broadcast gets to EspNetwork:channels[0] object!!!

-(void) opcodeReceived:(EspOpcode *)opcode fromChannel:(EspChannel *)channel
{
    NSAssert([[NSThread currentThread] isMainThread],@"attempt to process packet outside of main thread");
    [self handleOpcode:opcode];
    // this is basically a placeholder, as this function is supposed to do forwarding to other channels
}

// when a packet comes in on any EspChannel, process it locally and forward to other channels
-(void) packetReceived:(NSDictionary*)packet fromChannel:(EspChannel*)channel
{
    NSAssert([[NSThread currentThread] isMainThread],@"attempt to process packet outside of main thread");
    [self handleOldOpcode:packet];
    // we are disactivating the forwarding system below, while other things are finished and tested
    /*
    NSMutableDictionary* d = [NSMutableDictionary dictionaryWithDictionary:packet];
    if([packet objectForKey:@"sendTime"] == nil) // hasn't been rebroadcast yet
    {
        // organize timestamps for local processing of this first-hop packet
        [d setObject:[packet objectForKey:@"packetSendTime"] forKey:@"sendTime"];
        [d removeObjectForKey:@"packetSendTime"];
        [d setObject:[packet objectForKey:@"packetReceiveTime"] forKey:@"receiveTime"];
        [d removeObjectForKey:@"packetReceiveTime"];
        // preserve originating ip address
        [d setObject:[packet objectForKey:@"ip"] forKey:@"originAddress"];
        [self handleOpcode:d];
        
        // forward to all other channels
        // (individual channels might choose to ignore forwarding requests)
        [d removeObjectForKey:@"packetReceiveTime"];
        int opcode = [[d objectForKey:@"opcode"] intValue];
        for(EspChannel*c in channels) if(c != channel) [c sendOldOpcode:opcode withDictionary:d];
    }
    else
    {
        // organize timestamps for local processing of this forwarded packet (2nd hop or greater)
        // values of sendTime and sendTimeSystem are preserved as received
        [d setObject:[packet objectForKey:@"packetReceiveTime"] forKey:@"receiveTime"];
        [d removeObjectForKey:@"packetReceiveTime"];
        [d removeObjectForKey:@"packetSendTime"];
        [self handleOpcode:d];
        
        // forward to all other channels
        // (individual channels might choose to ignore forwarding requests)
        [d removeObjectForKey:@"receiveTime"];
        int opcode = [[d objectForKey:@"opcode"] intValue];
        for(EspChannel*c in channels) if(c != channel) [c sendOldOpcode:opcode withDictionary:d];
    }*/
}

-(void) handleOpcode: (EspOpcode*)opcode
{
    const char* ourName = [[[NSUserDefaults standardUserDefaults] stringForKey:@"person"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char* ourMach = [[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"] cStringUsingEncoding:NSUTF8StringEncoding];
    if(!strcmp(opcode->name,ourName) && !strcmp(opcode->machine, ourMach)) return; // ignore our own opcodes
    id<EspNetworkDelegate> h = handlers[opcode->opcode];
    if(h == nil) {
        NSString* s = [NSString stringWithFormat:@"no handler for opcode %d from %s-%s at %s",
                       opcode->opcode,opcode->name,opcode->machine,opcode->ip];
        postProblem(s,self);
        return;
    }
    NSString* log = [NSString stringWithFormat:@"received %s(%d) from %s-%s at %s",
                     opcodeName[opcode->opcode],opcode->opcode,opcode->name,opcode->machine,opcode->ip,nil];
    postLog(log, nil);
    [h handleOpcode:opcode];
}


-(void) handleOldOpcode: (NSDictionary*)d
{
    if([[d objectForKey:@"name"] isEqual:[[NSUserDefaults standardUserDefaults] stringForKey:@"person"]])
    {
        if([[d objectForKey:@"machine"] isEqual:[[NSUserDefaults standardUserDefaults] stringForKey:@"machine"]])
        {
            return; // name and machine are our own - so don't process message
        }
    }
    int opcode = [[d objectForKey:@"opcode"] intValue];
    id<EspNetworkDelegate> h = handlers[opcode];
    if(h == nil) {
        NSString* s = [NSString stringWithFormat:@"no handler for opcode %d from %@-%@ at %@",opcode,[d objectForKey:@"name"],[d objectForKey:@"machine"],[d objectForKey:@"originAddress"]];
        postProblem(s,self);
        return;
    }
    NSString* log = [NSString stringWithFormat:@"received %s(%d) from %@-%@ at %@",
                     opcodeName[opcode],
                     opcode,
                     [d objectForKey:@"name"],
                     [d objectForKey:@"machine"],
                     [d objectForKey:@"originAddress"]];
    postLog(log, nil);
    [h handleOldOpcode:d];
}

-(void) setHandler:(id)h forOpcode:(unsigned int)o
{
    NSAssert(o < ESPUDP_MAX_HANDLERS, @"attempt to add opcode handler beyond maximum");
    handlers[o] = h;
}


@end

void copyNameAndMachineIntoOpcode(EspOpcode* opcode)
{
    const char* name = [[[NSUserDefaults standardUserDefaults] objectForKey:@"person"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char* machine = [[[NSUserDefaults standardUserDefaults] objectForKey:@"machine"] cStringUsingEncoding:NSUTF8StringEncoding];
    strncpy(opcode->name,name,16);
    opcode->name[15] = 0; // i.e. make sure only 15 readable characters are included
    strncpy(opcode->machine,machine,16);
    opcode->machine[15] = 0;
}
