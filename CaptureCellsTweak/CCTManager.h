//
// Created by Lukas Arnold on 31.12.22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import "CCTBaseTweakManager.h"


@interface CCTManager : CCTBaseTweakManager

+ (instancetype)manager;

- (void)addData:(NSArray *)data;


@end