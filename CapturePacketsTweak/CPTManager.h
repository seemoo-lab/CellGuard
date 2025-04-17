//
// Created by Lukas Arnold on 05.06.23.
//

#import "CPTBaseTweakManager.h"


@interface CPTManager : CPTBaseTweakManager

+ (instancetype)manager;

- (void)addData:(NSData *)packetData :(NSString *)direction :(int)simSlot;


@end