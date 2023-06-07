//
// Created by Lukas Arnold on 31.12.22.
//

#import "CCTManager.h"


@interface CCTManager ()

- (NSString *)dataToJSON:(NSArray *)data timestamp:(NSTimeInterval)timestamp;

@property NSTimeInterval cellLastTimestamp;
@property NSArray *cellLastData;

@end

@implementation CCTManager {

}

+ (instancetype)manager {
    // https://stackoverflow.com/a/18622702
    return [[CCTManager alloc] initWithQueue:@"de.tudarmstadt.seemoo.cct.writeQueue"
            :@"CCTManager" :@"CaptureCellsTweak" :@"cells-cache.json"];
}

- (void)addData:(NSArray *)data {
    // If the array points to NULL, we'll just ignore it
    if (data == NULL) {
        return;
    }

    // If the new array is different or at least a second has passed, we'll save the array
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if ((now - self.cellLastTimestamp) > 1.0 || ![data isEqualToArray:self.cellLastData]) {
        self.cellLastTimestamp = now;
        self.cellLastData = [data copy];

        // https://stackoverflow.com/a/17453020
        // https://developer.apple.com/documentation/dispatch?language=objc
        // https://developer.apple.com/documentation/dispatch/1452927-dispatch_get_global_queue
        // https://developer.apple.com/documentation/dispatch/1453057-dispatch_async
        dispatch_async(self.writeQueue, ^(void) {
            // Print the capture data to the syslog
            [self log:@"CCTManager: writeQueue = %@", data];
            // Convert it into a JSON string and save it to a file
            [self writeData:[self dataToJSON:data timestamp:now]];
        });

    }
}

- (NSString *)dataToJSON:(NSArray *)data timestamp:(NSTimeInterval)timestamp {
    // Return an empty string if there's nothing to convert
    if (data == NULL || data.count == 0) {
        return @"";
    }

    // Add the current timestamp in an additional NSDictionary
    NSMutableArray *mutableData = [NSMutableArray arrayWithArray:data];
    [mutableData addObject:@{@"timestamp": @(timestamp)}];

    // Convert NSArray with the data into JSON format: https://stackoverflow.com/a/9020923
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:mutableData options:0 error:&error];
    // If the conversion to JSON was not successful, print an error and return nothing
    if (!jsonData) {
        [self log:@"CCTManager: Unable to convert data to JSON: %@\n%@", error, data];
        return @"";
    }

    // Convert the binary JSON data into a NSString
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    // and remove the 'kCTLCellMonitor' prefix to save space
    return [jsonString stringByReplacingOccurrencesOfString:@"kCTCellMonitor" withString:@""];
}

@end