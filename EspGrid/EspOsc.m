//
//  EspOsc.m
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

#import "EspOsc.h"
#import "EspGridDefs.h"

@implementation EspOsc
@synthesize echoToLog;

+(EspOsc*) osc
{
    static EspOsc* theSharedObject = nil;
    if(!theSharedObject) theSharedObject = [[super alloc] init];
    return theSharedObject;
}

-(id) init
{
    self = [super init];
    udp = [[EspSocket alloc] initWithPort:5510 andDelegate:self];
    handlers = [[NSMutableArray alloc] init];
    subscribers = [[EspOscSubscribers alloc] init];
    [subscribers setSocket:udp];
    echoToLog = FALSE;
    return self;
}

-(void) dealloc
{
    [subscribers release];
    [udp release];
    [handlers release];
    [super dealloc];
}

-(void) addHandler:(id<EspHandleOsc>)handler forAddress:(NSString*)address
{
    NSArray* x = [NSArray arrayWithObjects:address,handler,nil];
    [handlers addObject:x];
}

-(void)packetReceived:(NSDictionary *)packet
{
    NSAssert([[NSThread currentThread] isMainThread],@"attempt to process packet outside main thread");
    NSData* d = [packet objectForKey:@"data"];
    NSString* h = [packet objectForKey:@"host"];
    int p = [[packet objectForKey:@"port"] intValue];
    
    @try
    {
        NSAssert(d!=nil, @"d is nil in EspOsc dataReceived");
        unsigned long limit = [d length];
        NSAssert(limit!=0, @"data has 0 length in EspOsc dataReceived");
        const char* data = [d bytes];
        int i = 0;

        // parse the address (everything from beginning to first 0 byte, index rounded up to blocks of 4
        NSString* address;
        @try { address = [NSString stringWithUTF8String:data]; }
        @catch (NSException *exception)
        {
            postWarning(@"unable to parse OSC address from received data (exception)",self);
            return;
        }
        if(address == nil)
        {
            postWarning(@"unable to parse OSC address from received data (nil result)",self);
            return;
        }
        while(data[i] != 0 && i<limit) i++;
        i = i + (4-(i%4));
    
        // parse the format string
        if(i>=limit) { postWarning(@"received OSC without format string",self); return; }
        NSString* format = [NSString stringWithUTF8String:data+i+1];
        unsigned long nParams = [format length];
        while(data[i] != 0) i++;
        i = i + (4-(i%4));
        
        // parse the parameters
        
        NSMutableArray* params = [[NSMutableArray alloc] init];
        
        int x = 0;
        
        while(x<nParams)
        {
            unichar c = [format characterAtIndex:x];
            
            if(c == 'i')
            {
                if(i>=limit) { postWarning(@"OSC message missing int parameter",self); return; }
                int r = *((int*)(data+i));
                int swapped = EspSwapInt32(r);
				NSLog(@"int %d",swapped);
                NSNumber* n = [NSNumber numberWithInt:swapped];
                [params addObject:n];
                i+=4;
            }
            else if(c == 'f')
            {
                if(i>=limit) { postWarning(@"OSC message missing float parameter",self); return; }
				UInt32 r = *((UInt32*)(data+i));
				r = EspSwapInt32(r);
                float f =   *((float *)(&r));
                NSNumber* n = [NSNumber numberWithFloat:f];
                [params addObject:n];
                i+=4;
            }
            else if(c == 's')
            {
                if(i>=limit) { postWarning(@"OSC message missing string parameter",self); return; }
                
                // *** still need to add better protection/recovery here against ill-formatted OSC
                NSString* s;
                @try { s = [NSString stringWithUTF8String:data+i]; }
                @catch (NSException* e)
                {
                    postWarning(@"unable to parse OSC string parameter (exception)",self);
                    return;
                }
                if(s == nil)
                {
                    postWarning(@"unable to parse OSC string parameter (nil result)",self);
                    return;
                }
                [params addObject:s];
                while(data[i] != 0 && i<limit) i++;
                i = i + (4-(i%4)); 
            }
            x++;
        }
        
        if(i>limit)
        {
            postWarning(@"unable to parse OSC parameters (parsing beyond limit)", self);
            return;
        }
        
        if(echoToLog)
        {
            NSMutableString* s = [NSMutableString stringWithFormat:@"OSC received from %@:%d: %@ ",h,p,address];
            for(id x in params)
            {
                [s appendString:[NSString stringWithFormat:@"%@ ",x,nil]];
            }
            postLog(s,nil);
        }
        
        // call any registered handler, passing the address and params
        int c = 0;
        for(NSArray* x in handlers)
        {
            if([[x objectAtIndex:0] isEqual:address])
            {
                [[x objectAtIndex:1] handleOsc:address withParameters:params fromHost:h port:p];
                c++;
            }
        }
        if(c == 0)
        {
            NSString* l = [NSString stringWithFormat:@"public protocol received unknown OSC address %@",address];
            postProblem(l, self);
        }
    }
    @catch (NSException* exception)
    {
        NSString* msg = [NSString stringWithFormat:@"EXCEPTION in dataReceived: %@: %@",[exception name],[exception reason]];
        postProblem(msg, self);
        @throw;
    }
}

+(NSMutableData*) createOscMessage:(NSArray*)msg log:(BOOL)log
{
    NSMutableData* d = [[[NSMutableData alloc] initWithCapacity: 256] autorelease];
    
    // add address to data packet
    NSString* address = [msg objectAtIndex:0];
    [d appendData:[address dataUsingEncoding:NSUTF8StringEncoding]];
    [d increaseLengthBy: (4-([address length]%4))];
    NSMutableString* logString = [NSMutableString stringWithFormat:@"sending %@ ",address];
    
    // append format string
    NSMutableString* formatString = [NSMutableString stringWithString:@","];
    long l = [msg count];
    for(int x=1;x<l;x++)
    {
        NSObject *o = [msg objectAtIndex:x];
        if([o isKindOfClass:[NSString class]])[formatString appendFormat:@"s"];
        else if([o isKindOfClass:[NSNumber class]])
        {   // NSNumber could be an int or a float
            NSNumber* n = (NSNumber*)o;
            const char* t = [n objCType];
            if(t[0] == 'i') [formatString appendFormat:@"i"];
            else if(t[0] == 'q') [formatString appendFormat:@"i"];
            else if(t[0] == 'f') [formatString appendFormat:@"f"];
            else if(t[0] == 'd') [formatString appendFormat:@"d"];
            else @throw [NSException exceptionWithName:@"problem" reason:@"unhandled NSNumber objCType in createOscMessage" userInfo:nil];
        }
        else @throw [NSException exceptionWithName:@"problem" reason:@"unrecognized parameter " userInfo:nil];
    }
    [d appendData:[formatString dataUsingEncoding:NSUTF8StringEncoding]];
    [d increaseLengthBy:(4-([formatString length]%4))];
    
    // append data items
    for(int x=1;x<l;x++)
    {
        NSObject *o = [msg objectAtIndex:x];
        if([o isKindOfClass:[NSString class]])
        {   // append string data
            NSString* str = (NSString*)o;
            [d appendData: [str dataUsingEncoding:NSUTF8StringEncoding]];
            [d increaseLengthBy:(4-([str length]%4))];
            [logString appendFormat:@"%@ ",str];
        }
        else if([o isKindOfClass:[NSNumber class]])
        {
            NSNumber* n = (NSNumber*)o;
            const char* t = [n objCType];
            if(t[0] == 'i')
            { // append int data
                int x = EspSwapInt32([n intValue]);
                [d appendBytes:&x length:4];
                [logString appendFormat:@"%d ",[n intValue]];
            }
            else if(t[0] == 'q')
            { // append long long data as an int ???
                int x = EspSwapInt32([n intValue]);
                [d appendBytes:&x length:4];
                [logString appendFormat:@"%d ",[n intValue]];
            }
            else if(t[0] == 'f') 
            { // append float data
                float y = EspSwapFloat32([n floatValue]);
                [d appendBytes:&y length:4];
                [logString appendFormat:@"%f ",[n floatValue]];
            }
            else if(t[0] == 'd')
            { // append double data (note: not part of OSC 1.0 required spec and unsupported by many OSC applications)
                double y = EspSwapFloat64([n doubleValue]);
                [d appendBytes:&y length:8];
                [logString appendFormat:@"%lf ",[n doubleValue]];
            }
        }
    }
    if(log)postLog(logString,nil);
    return d;
}


-(void) transmit:(NSArray*)msg toHost:(NSString*)h port:(int)p log:(BOOL)log
{
    @try
    {
        NSMutableData* d = [EspOsc createOscMessage:msg log:log];
        if(d != nil) [udp sendData:d toHost:h port:p];
        if(echoToLog)
        {
            NSMutableString* s = [NSMutableString stringWithFormat:@"OSC sent to %@:%d: ",h,p,nil];
            for(id x in msg)
            {
                [s appendString:[NSString stringWithFormat:@"%@ ",x,nil]];
            }
            postLog(s,nil);
        }
    }
    @catch (NSException* exception)
    {
        NSString* msg = [NSString stringWithFormat:@"EXCEPTION in transmit:toHost:port:log %@: %@",[exception name],[exception reason]];
        postProblem(msg, self);
        @throw;
    }
}


-(void) transmit:(NSArray*)msg log:(BOOL)log
{
    @try
    {
        NSMutableData* d = [EspOsc createOscMessage:msg log:log];
        if(d != nil) [self transmitData:d];
        {
            NSMutableString* s = [NSMutableString stringWithFormat:@"OSC sent to all subscribers: ",nil];
            for(id x in msg)
            {
                [s appendString:[NSString stringWithFormat:@"%@ ",x,nil]];
            }
            postLog(s,nil);
        }
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat:@"EXCEPTION in transmit:log %@: %@",[exception name],[exception reason]];
        postProblem(msg, self);
        @throw;
    }
}


-(void) transmitData: (NSData*)data
{
    [subscribers sendData:data];
}

-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    return [subscribers handleOsc:address withParameters:d fromHost:h port:p];
}


-(void) response:(NSString*)address value:(NSObject*)v toQuery:(NSArray*)d fromHost:(NSString*)h port:(int)p
{
    NSArray* msg = [NSArray arrayWithObjects:address,v,nil];
    if([d count] == 0) [self transmit:msg toHost:h port:p log:NO]; // respond to query source
    else if([d count] == 1) [self transmit:msg toHost:h port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port, deduced host
    else if([d count] == 2) [self transmit:msg toHost:[d objectAtIndex:1] port:[[d objectAtIndex:0] intValue] log:NO]; // explicit port+host
    else postProblem([NSString stringWithFormat:@"received %@ with too many params",address,nil], self);
}

@end
