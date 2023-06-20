//
// Created by Lukas Arnold on 05.06.23.
//

#import "CPTManager.h"


@interface CPTManager ()

@end

@implementation CPTManager {

}

+ (instancetype)manager {
    // https://stackoverflow.com/a/18622702
    return [[CPTManager alloc] initWithQueue:@"de.tudarmstadt.seemoo.cpt.writeQueue"
            :@"CPTManager" :@"CapturePacketsTweak" :@"packets-cache.json"];
}

- (void)addData:(NSData *)packetData :(NSString *)direction; {
    // If the packet data is null, we'll just ignore it
    if (packetData == NULL) {
        return;
    }

    // If the new array is different or at least a second has passed, we'll save the array
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    NSMutableString *entry = [NSMutableString stringWithString:direction];
    [entry appendString:@","];
    [entry appendString:[packetData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]];
    [entry appendString:@","];
    [entry appendFormat:@"%lf", now];

    // https://stackoverflow.com/a/17453020
    // https://developer.apple.com/documentation/dispatch?language=objc
    // https://developer.apple.com/documentation/dispatch/1452927-dispatch_get_global_queue
    // https://developer.apple.com/documentation/dispatch/1453057-dispatch_async
    dispatch_async(self.writeQueue, ^(void) {
        // Print the captured data to the syslog
        [self log:@"writeQueue = %@", entry];
        [self writeData:entry];
    });
}

@end