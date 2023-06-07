//
// Created by Lukas Arnold on 31.12.22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import "BaseTweakManager.h"


@interface CCTManager : BaseTweakManager

+ (instancetype)manager;

- (void)addData:(NSArray *)data;


@end