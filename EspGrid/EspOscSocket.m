//
//  EspOscSocket.m
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2016 by David Ogborn.
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

#import "EspOscSocket.h"
#import "EspGridDefs.h"
#import <unistd.h>

#ifdef _WIN32
#import <Ws2tcpip.h>
#endif

@implementation EspOscSocket
@synthesize delegate;

-(id) initWithPort: (int)p andDelegate:(id<EspOscSocketDelegate>)d
{
    self = [super init];
    transmitData = [[NSMutableData alloc] initWithLength:ESP_OSC_SOCKET_BUFFER_SIZE];
    if(!transmitData) { postProblem(@"unable to allocate transmitData", self); }
    transmitBuffer = (void*)[transmitData bytes];
    receiveData = [[NSMutableData alloc] initWithLength:ESP_OSC_SOCKET_BUFFER_SIZE];
    if(!receiveData) { postProblem(@"unable to allocate receiveData", self); }
    receiveBuffer = (void*)[receiveData bytes];
    if(!receiveData) { postProblem(@"unable to allocate receiveData", self); }
    socketRef = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(socketRef == -1) { postProblem(@"unable to create socket",self); }
    #ifndef _WIN32
    int reuseOn = 1;
    #else
    const char reuseOn = 1;
    #endif
    setsockopt(socketRef, SOL_SOCKET, SO_BROADCAST, &reuseOn, sizeof(reuseOn));
    [self setDelegate:d];
    port = p;
    if([self bindToPort:port] == YES)
    {
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(udpReceiveLoop) object:nil];
        [thread start];
    }
    return self;
}

-(void) dealloc
{
    close(socketRef);
    [receiveData release];
    free(receiveBuffer);
    [transmitData release];
    free(transmitBuffer);
    [super dealloc];
}

-(BOOL) bindToPort:(unsigned int)p
{
    #ifndef _WIN32
    int reuseOn = 1;
    #else
    const char reuseOn = 1;
    #endif
    setsockopt(socketRef, SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn)); // maybe this isn't necessary?

    #ifndef _WIN32
    int timestamp = 1;
    int r = setsockopt(socketRef, SOL_SOCKET, SO_TIMESTAMP, &timestamp, sizeof(timestamp));
    if(r!=0) postProblem(@"unable to set socket option", self);
    #endif

    // us.sin_len = sizeof(struct sockaddr_in); // probably needs to be commented out on Linux, seems to ok without on Cocoa too though
    us.sin_family = AF_INET;
    us.sin_port = htons(p);
    us.sin_addr.s_addr = htonl(INADDR_ANY);
    memset(&(us.sin_zero), 0, sizeof(us.sin_zero));
    if (bind(socketRef, (const struct sockaddr*)&us, sizeof(us)) < 0) {
        NSString* s = [NSString stringWithFormat:@"unable to bind to port %d",p];
        postProblem(s,self);
        close(socketRef);
        return NO;
    }
    NSString* l = [NSString stringWithFormat:@"bound to UDP port %d",p];
    postLog(l,self);
    return YES;
}

-(void) udpReceiveLoop
{
    [NSThread setThreadPriority:0.5];
    for(;;)
    {
    #ifdef GNUSTEP
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init]; // was this necessary for GNUstep,or...? it produces a segfault on OSX sometimes
    #endif
    #ifndef _WIN32
        struct msghdr msg;
        struct iovec entry;
        struct { struct cmsghdr cm; char control[512]; } control;
        memset(&msg, 0, sizeof(msg));
        msg.msg_iov = &entry;
        msg.msg_iovlen = 1;
        entry.iov_base = receiveBuffer;
        entry.iov_len = ESP_OSC_SOCKET_BUFFER_SIZE;
        msg.msg_name = (caddr_t)&them;
        msg.msg_namelen = sizeof(them);
        msg.msg_control = &control;
        msg.msg_controllen = sizeof(control);
        long n = recvmsg(socketRef, &msg, 0);
    #else
        int s = sizeof(them);
        long n = recvfrom(socketRef, receiveBuffer, ESP_OSC_SOCKET_BUFFER_SIZE, 0, (struct sockaddr*)&them, &s);
    #endif
        EspTimeType monotonic = monotonicTime();
        if(n>ESP_OSC_SOCKET_BUFFER_SIZE)
        {
            postProblem(@"received more data than buffer can handle",self);
            continue;
        }
        if(n>0) {

            (*(char*)(receiveBuffer+n)) = 0;
            NSString* h = [NSString stringWithCString:inet_ntoa(them.sin_addr) encoding:NSASCIIStringEncoding];
            NSData* d = [[NSData alloc] initWithBytesNoCopy:receiveBuffer length:n freeWhenDone:NO];
            them.sin_port = ntohs(them.sin_port);
            @try {
                NSDictionary* packet = [NSDictionary dictionaryWithObjectsAndKeys:
                                        d,@"data",h,@"host",[NSNumber numberWithInt:them.sin_port],@"port",
                                        [NSNumber numberWithUnsignedLongLong:monotonic],@"monotonicTime",nil];
                [delegate performSelectorOnMainThread:@selector(packetReceived:) withObject:packet waitUntilDone:YES];
            }
            @catch (NSException* exception) {
                NSString* msg = [NSString stringWithFormat:@"EXCEPTION in udpReceiveLoop: %@: %@",[exception name],[exception  reason]];
                postProblem(msg, nil);
                @throw;
            }
            [d release];
#ifdef GNUSTEP
	    [pool drain];
#endif
        }
        else if (n==-1)
        {
            NSLog(@"***udpReceiveLoop error: %s",strerror(errno));
        }
    }
}

static void sendOscData(int socketRef,const void* data,size_t length,NSString* host,int port)
{
    assert([[NSThread currentThread] isMainThread]); // don't allow transmission other than from main thread
    if(host == nil) { postProblem(@"can't send when host==nil",nil); return; }
    if(port == 0) { postProblem(@"can't send when port==0",nil); return; }
    struct sockaddr_in address;
    // address.sin_len = sizeof(struct sockaddr_in); // this line needs to be commented out for GNUstep, apparently ok without on cocoa
    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    inet_pton(AF_INET, [host UTF8String], &(address.sin_addr.s_addr));
    memset(&(address.sin_zero), 0, sizeof(address.sin_zero));
    ssize_t r = sendto(socketRef, data, length, 0, (struct sockaddr*)&address, (socklen_t)sizeof(address));
    if(r != length) NSLog(@"*** sendto unable to send all %ld bytes to %@, bytes sent = %ld",length,host,r);
}

-(void)sendData: (NSData*)data toHost:(NSString*)host port:(int)p
{
    sendOscData(socketRef, [data bytes], [data length], host, p); // use a specific port indicated by argument p
}

-(void)sendData: (NSData*)data toHost:(NSString*)host
{
    sendOscData(socketRef, [data bytes], [data length], host, port); // use the port on which we listen
}

@end
