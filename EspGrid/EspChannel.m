//
//  EspChannel.m
//  EspGrid
//
//  Created by David Ogborn on 2014-03-30.
//
//

#import "EspChannel.h"

@implementation EspChannel
@synthesize host, port, delegate;


-(void) setPort:(int)p
{
    port = p;
    EspSocket* oldSocket = socket;
    socket = [[EspSocket alloc] initWithPort:p andDelegate:self];
    [oldSocket release];
}


-(void) sendDictionaryWithTimes:(NSDictionary*)d
{
    NSError* err = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:d
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&err];
    if(err != nil) @throw([NSException exceptionWithName:@"serialization" reason:@"unknown" userInfo:nil]);
    [socket sendDataWithTimes:data toHost:host];
}


// note: don't override this in subclasses - override afterDataReceived: instead
-(void)packetReceived:(NSDictionary *)packet
{
    NSAssert([[NSThread currentThread] isMainThread],@"attempt to process packet outside main thread");
    NSData* d = [packet objectForKey:@"data"];
    NSString* h = [packet objectForKey:@"host"];
    int p = [[packet objectForKey:@"port"] intValue];
    EspTimeType monotonicTime = [[packet objectForKey:@"monotonicTime"] longLongValue];
    
    NSAssert(d != nil, @"data should not be nil in EspChannel::dataReceived...");
    NSAssert(h != nil, @"host should not be nil in EspChannel::dataReceived...");
    EspTimeType packetSendTime = *((EspTimeType*)[d bytes]); // first 8 bytes are monotonic send time
    NSData* temp = [NSData dataWithBytesNoCopy:[d bytes]+8 length:[d length]-8 freeWhenDone:NO];
    NSError* err = nil;
    NSMutableDictionary* plist =
    (NSMutableDictionary*)[NSPropertyListSerialization propertyListWithData:temp
                                                                    options:NSPropertyListMutableContainers
                                                                     format:NULL error:&err];
    if(plist != nil)
    {
        [plist setValue:h forKey:@"ip"];
        [plist setValue:[NSNumber numberWithInt:p] forKey:@"port"];
        [plist setValue:[NSNumber numberWithLongLong:packetSendTime] forKey:@"packetSendTime"];
        [plist setValue:[NSNumber numberWithLongLong:monotonicTime] forKey:@"packetReceiveTime"];
        [self afterDataReceived:plist];
    }
    else
    {
        NSString* s = [NSString stringWithFormat:@"unable to deserialize packet from %@:%d (%lu bytes)",
                       h,p,[d length]];
        postProblem(s, self);
    }
}

// override this in subclasses in order to add custom behaviours upon receipt of a timestamped packet
// overridden methods can call [super afterDataReceived] to ensure packet is processed by EspNetwork
-(void) afterDataReceived:(NSDictionary*)plist
{
    [delegate packetReceived:plist fromChannel:self];
}

@end
