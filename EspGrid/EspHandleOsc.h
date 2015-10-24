//
//  EspHandleOsc.h
//  EspGrid
//
//  Created by David Ogborn on 2015-10-24.
//
//

#ifndef EspGrid_EspHandleOsc_h
#define EspGrid_EspHandleOsc_h

@protocol EspHandleOsc <NSObject>
-(BOOL) handleOsc:(NSString*)address withParameters:(NSArray*)d fromHost:(NSString*)h port:(int)p;
@end

#endif
