//
//  EspMovingAverage.m
//  EspGrid
//
//  Created by David Ogborn on 1/27/2014.
//
//

#import "EspMovingAverage.h"

@implementation EspMovingAverage

-(id) initWithLength:(int)l
{
    self = [super init];
    length = l;
    count = 0;
    index = 0;
    array = malloc(sizeof(EspTimeType)*l);
    memset(array, 0, sizeof(EspTimeType)*l);
    accumulator = 0;
    return self;
}

-(void) dealloc
{
    free(array);
    [super dealloc];
}

-(EspTimeType) push:(EspTimeType)x
{
    accumulator += x; // add the new value
    accumulator -= array[index]; // subtract the oldest value
    if(count<length) count++; // count how many values we have
    array[index] = x; // store the new value
    index = (index + 1) % length; // advance and wraparound
    return accumulator/count;
}

@end
