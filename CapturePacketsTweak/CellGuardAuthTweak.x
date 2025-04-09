
#import <Foundation/Foundation.h>

%hook TweakAuthManager

- (NSString *)key {
    NSLog(@"HOOKED key called");
    return @"Hooked";
}

%end
