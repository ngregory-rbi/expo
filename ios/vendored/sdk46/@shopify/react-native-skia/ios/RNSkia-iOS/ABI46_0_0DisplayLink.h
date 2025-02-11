#pragma once

#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

typedef void (^block_t)(double);
@interface ABI46_0_0DisplayLink : NSObject {
  CADisplayLink *_displayLink;
}

@property(nonatomic, copy) block_t updateBlock;

- (void)start:(block_t)block;

- (void)stop;

@end
