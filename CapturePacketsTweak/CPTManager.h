//
// Created by Lukas Arnold on 05.06.23.
//

#import "BaseTweakManager.h"


@interface CPTManager : BaseTweakManager

+ (instancetype)manager;

- (void)addData:(NSData *)packetData :(NSString *)direction;


@end