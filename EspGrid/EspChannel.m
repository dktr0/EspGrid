//
//  EspChannel.m
//  EspGrid
//
//  Created by David Ogborn on 2014-03-30.
//
//

#import "EspChannel.h"

@implementation EspChannel
@synthesize host, delegate;

-(id) init
{
    self = [super init];
    port = 0;
    socket = NULL;
    return self;
}

-(int) port
{
    return port;
}

-(void) setPort:(int)p
{
    if(p != port)
    {
        port = p;
        EspSocket* oldSocket = socket;
        socket = [[EspSocket alloc] initWithPort:p andDelegate:self];
        [oldSocket closeSocket];
        [oldSocket release];
    }
}


-(void) sendOldOpcode:(int)n withDictionary:(NSDictionary *)d
{
    [socket sendOldOpcode:n withDictionary:d toHost:host];
}

-(void) sendOpcode:(EspOpcode*)opcode
{
    [socket sendOpcode:opcode toHost:host];
}

// note: don't override this in subclasses - override handleOpcode: (new style) and afterDataReceived: (old) instead
-(void)opcodeReceived:(NSData*)data
{
    NSAssert([[NSThread currentThread] isMainThread],@"attempt to process opcode outside main thread");
    EspOpcode* opcode = (EspOpcode*)[data bytes];
    if(opcode->opcode == ESP_OPCODE_BEACON || opcode->opcode == ESP_OPCODE_ACK)
    {
        // received opcode is a new-style opcode
        [self afterOpcodeReceived:opcode];
    }
    else
    {
        // received opcode is an old-style, NSDictionary based opcode, so dictionary needs to be built...
        char* data = ((char*)opcode) + sizeof(EspOpcode);
        NSData* temp = [NSData dataWithBytesNoCopy:data length:(opcode->length-sizeof(EspOpcode)) freeWhenDone:NO];
        NSError* err = nil;
        NSMutableDictionary* plist = (NSMutableDictionary*)[NSPropertyListSerialization
                                                            propertyListWithData:temp options:NSPropertyListMutableContainers
                                                            format:NULL error:&err];
        if(plist != nil)
        {
            [plist setValue:[NSNumber numberWithChar:opcode->opcode] forKey:@"opcode"];
            [plist setValue:[NSString stringWithCString:opcode->ip encoding:NSUTF8StringEncoding] forKey:@"ip"];
            [plist setValue:[NSNumber numberWithInt:opcode->port] forKey:@"port"];
            [plist setValue:[NSNumber numberWithLongLong:opcode->sendTime] forKey:@"packetSendTime"];
            [plist setValue:[NSNumber numberWithLongLong:opcode->receiveTime] forKey:@"packetReceiveTime"];
            [self afterDataReceived:plist];
        }
        else
        {
            NSString* s = [NSString stringWithFormat:@"unable to deserialize dictionary from %s:%d (%u bytes)",
                           opcode->ip,opcode->port,opcode->length];
            postProblem(s, self);
        }
    }
}

// override these in subclasses in order to add custom behaviours upon receipt of a timestamped packet
// overridden methods can call [super afterDataReceived] to ensure packet is processed by EspNetwork
-(void) afterDataReceived:(NSDictionary*)plist
{
    [delegate packetReceived:plist fromChannel:self];
}

-(void) afterOpcodeReceived:(EspOpcode*)opcode
{
    [delegate opcodeReceived:opcode fromChannel:self];
}

@end
