//
//  EspSocket.h
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
#import "EspGridDefs.h"
#ifdef MINGW
#import <Winsock2.h>
#else
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <netdb.h>
#endif

@protocol EspSocketDelegate
- (void)dataReceived:(NSData*)d fromHost:(NSString*)h fromPort:(int)port systemTime:(EspTimeType)timestamp monotonicTime:(EspTimeType)monotonic;
@end

#define ESP_SOCKET_BUFFER_SIZE 2048

@interface EspSocket : NSObject
{
    int socketRef, port;
    struct sockaddr_in us;
    NSThread* thread;
    struct sockaddr_in them;
    id<EspSocketDelegate> delegate;
    NSLock* transmitLock;
    void* transmitBuffer;
    NSMutableData* transmitData;
    void* receiveBuffer;
    NSMutableData* receiveData;
}
@property (nonatomic,assign) id<EspSocketDelegate> delegate;

-(id) initWithPort:(int)p andDelegate:(id<EspSocketDelegate>)delegate;
-(BOOL) bindToPort:(unsigned int)p;
-(void) sendData:(NSData*)data toHost:(NSString*)host; // send to whatever port we listen on
-(void) sendData:(NSData*)data toHost:(NSString*)host port:(int)p; // send to an arbitrary port
-(void) sendDataWithTimes:(NSData*)data toHost:(NSString*)host; // send to whatever port we listen on
-(void) sendDataWithTimes:(NSData*)data toHost:(NSString*)host port:(int)p; // send to an arbitrary port

@end



