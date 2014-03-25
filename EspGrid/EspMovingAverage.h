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
{
    int length; // length of moving average filter
    int count; // current number of values in storage
    int index; // an index for a ring buffer
    EspTimeType* array; // memory for a ring buffer
    EspTimeType accumulator; // efficient update of sum
}

-(id) initWithLength:(int)l;
-(EspTimeType) push:(EspTimeType)x;
@end
