//
//  EspChannel.h
//  EspGrid
//
//  Created by David Ogborn on 2014-03-30.
//
//

#import <Foundation/Foundation.h>
#import "EspOpcode.h"
#import "EspSocket.h"

@class EspChannel;

@protocol EspChannelDelegate
-(void) packetReceived:(NSDictionary*)packet fromChannel:(EspChannel*)channel; // old-style, still necessary for now
-(void) opcodeReceived:(EspOpcode*)opcode fromChannel:(EspChannel*)channel; // new-style
@end

@interface EspChannel : NSObject <EspSocketDelegate>
{
    int port;
    NSString* host;
    EspSocket* socket;
    id delegate;
}
@property (nonatomic,assign) int port;
@property (nonatomic,copy) NSString* host;
@property (nonatomic,assign) id delegate;

-(void) sendOldOpcode:(int)n withDictionary:(NSDictionary*)d; // old method
-(void) sendOpcode:(EspOpcode*)opcode; // new method
-(void) afterDataReceived:(NSDictionary*)plist; // old method
-(void) afterOpcodeReceived:(EspOpcode*)opcode; // new method

@end
