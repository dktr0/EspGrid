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

-(id) init
{
    self = [super init];
    if(self)
    {
        lock = [[NSLock alloc] init];
    }
    return self;
}

-(void) dealloc
{
    [lock release];
    [super dealloc];
}

-(void) setPort:(int)p
{
    [lock lock];
    port = p;
    [socket release];
    socket = [[EspSocket alloc] initWithPort:p andDelegate:self];
    [lock unlock];
}

-(void) setHost:(NSString*)h
{
    [lock lock];
    [host release];
    host = [h copy];
    [lock unlock];
}

-(void) setDelegate:(id)d
{
    [lock lock];
    delegate = d;
    [lock unlock];
}


-(void) sendDictionaryWithTimes:(NSDictionary*)d
{
    [lock lock];
    NSError* err = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:d
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&err];
    if(err != nil) @throw([NSException exceptionWithName:@"serialization" reason:@"unknown" userInfo:nil]);
    [socket sendDataWithTimes:data toHost:host];
    [lock unlock];
}


// note: don't override this in subclasses - override afterDataReceived: instead
- (void)dataReceived:(NSData*)d fromHost:(NSString*)h fromPort:(int)p systemTime:(EspTimeType)timestamp monotonicTime:(EspTimeType)monotonic;
{
    NSAssert(d != nil, @"data should not be nil in EspChannel::dataReceived...");
    NSAssert(h != nil, @"host should not be nil in EspChannel::dataReceived...");
    EspTimeType packetSendTime = *((EspTimeType*)[d bytes]); // first 8 bytes are monotonic send time
    EspTimeType packetSendTimeSystem = *((EspTimeType*)([d bytes]+8)); // next 8 are system send time
    NSData* temp = [NSData dataWithBytesNoCopy:[d bytes]+16 length:[d length]-16 freeWhenDone:NO];
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
        [plist setValue:[NSNumber numberWithLongLong:packetSendTimeSystem] forKey:@"packetSendTimeSystem"];
        [plist setValue:[NSNumber numberWithLongLong:monotonic] forKey:@"packetReceiveTime"];
        [plist setValue:[NSNumber numberWithLongLong:timestamp] forKey:@"packetReceiveTimeSystem"];
        [self performSelectorOnMainThread:@selector(afterDataReceived:) withObject:plist waitUntilDone:NO];
    }
    else
    {
        NSString* s = [NSString stringWithFormat:@"unable to deserialize packet from %@ (%lu bytes)",
                       h,[d length]];
        postProblem(s, self);
    }
}

// override this in subclasses in order to add custom behaviours upon receipt of a timestamped packet
// overridden methods should call [super afterDataReceived]
-(void) afterDataReceived:(NSDictionary*)plist
{
    [delegate packetReceived:plist fromChannel:self];
}

@end
