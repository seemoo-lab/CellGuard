//
// Created by Lukas Arnold on 07.06.23.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>

@interface BaseTweakManager : NSObject

- (instancetype)initWithQueue:(NSString *)queueName :(NSString *)logPrefix :(NSString *)tweakName :(NSString *)cacheFileName;

- (void)log:(NSString *)format, ...;

- (void)listen:(int)port;

@property dispatch_queue_t writeQueue;

- (void)writeData:(NSString *)dataString;

- (void)close;

@end