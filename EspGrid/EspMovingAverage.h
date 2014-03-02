//
//  EspMovingAverage.h
//  EspGrid
//
//  Created by David Ogborn on 1/27/2014.
//
//

#import <Foundation/Foundation.h>
#import "EspGridDefs.h"

@interface EspMovingAverage : NSObject
-(id) initWithLength:(int)l;
-(EspTimeType) push:(EspTimeType)x;
@end
