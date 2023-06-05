//
// Created by Lukas Arnold on 31.12.22.
//

#import "CCTManager.h"


@interface CCTManager ()

- (NSURL *)cacheFile;

- (void)handleInboundConnection:(nw_connection_t)connection;

- (void)emptyCache;

- (void)closeConnection;

- (NSString *)dataToJSON:(NSArray *)data timestamp:(NSTimeInterval)timestamp;

- (void)writeData:(NSString *)data;

@end

@implementation CCTManager {

}


- (void)listen:(int)port {
    // https://developer.apple.com/documentation/network/implementing_netcat_with_network_framework?language=objc

    // Create parameters for listing to an inbound TCP connection without TLS
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(
            NW_PARAMETERS_DISABLE_PROTOCOL,
            NW_PARAMETERS_DEFAULT_CONFIGURATION
    );

    // Only listen on the interface 127.0.0.1 and the given port
    const char *portString = [[@(port) stringValue] UTF8String];
    nw_endpoint_t endpoint = nw_endpoint_create_host("127.0.0.1", portString);
    nw_parameters_set_local_endpoint(parameters, endpoint);

    // Create the listener with the specified parameters
    self.nw_listener = nw_listener_create(parameters);
    if (self.nw_listener == NULL) {
        NSLog(@"CCTManager: Can't create a TCP listener on port %d", port);
        return;
    }

    // If callback functions are called using the specified the queue
    nw_listener_set_queue(self.nw_listener, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    // Function to handle state changes
    nw_listener_set_state_changed_handler(self.nw_listener, ^(nw_listener_state_t state, nw_error_t error) {
        NSLog(@"CCTManager: Network state changed %u - %@", state, error);
    });
    // Function to handle new connection
    nw_listener_set_new_connection_handler(self.nw_listener, ^(nw_connection_t connection) {
        [self handleInboundConnection:connection];
    });

    // Start the listener
    nw_listener_start(self.nw_listener);

    NSLog(@"CCTManager: Opened port %d", port);

}

- (void)handleInboundConnection:(nw_connection_t)connection {
    NSLog(@"CCTManager: New connection %@", connection);

    // If there's already an open connection, we'll cancel the incoming one
    if (self.nw_inbound_connection != NULL) {
        nw_connection_cancel(connection);
        return;
    }

    // Store the connection and assign it a queue
    self.nw_inbound_connection = connection;
    nw_connection_set_queue(self.nw_inbound_connection, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    nw_connection_set_state_changed_handler(self.nw_inbound_connection, ^(nw_connection_state_t state, nw_error_t error) {
        NSLog(@"CCTManager: Connection State Changed %@: %d %@", connection, state, error);
    });
    nw_connection_start(self.nw_inbound_connection);

    // Get the path of the cache file
    NSURL *cacheFile = self.cacheFile;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Close the connection as the cache file is empty
    if (![fileManager fileExistsAtPath:cacheFile.path]) {
        [self closeConnection];
        return;
    }

    // Read the full content of the file into memory to lock the file as short as possible
    NSError *fileError;
    NSData *data = [NSData dataWithContentsOfURL:cacheFile options:0 error:&fileError];
    if (fileError) {
        NSLog(@"CCTManager: Can't read the file %@ into memory: %@", cacheFile.path, fileError);
        [self closeConnection];
        return;
    }

    // Convert the data read from NSData into dispatch_data_t
    // It's important to use malloc and not to store this amount of data on the stack
    // See: https://stackoverflow.com/a/4116966
    char* bytes = malloc(data.length);
    if (bytes == NULL) {
        NSLog(@"CCTManager: Can't malloc %lu bytes for sending the file", data.length);
    }
    [data getBytes:bytes length:data.length];
    // Free the bytes array when the dispatch_data_t object is destroyed
    // See: https://developer.apple.com/documentation/dispatch/dispatch_data_destructor_free
    dispatch_data_t sendData = dispatch_data_create(bytes, data.length, NULL, DISPATCH_DATA_DESTRUCTOR_FREE);

    // Send the data over the wire
    nw_connection_send(self.nw_inbound_connection, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
            ^(nw_error_t _Nullable error) {
                if (error != NULL) {
                    // Print an error
                    NSLog(@"CCTManager: Can't send data over the wire: %@", error);
                } else {
                    // If everything was successful, clear the cache file
                    [self emptyCache];
                }
                // In any case, close the connection
                [self closeConnection];
            });
}

- (void)emptyCache {
    // Get a file handle for the cache file
    NSError *error;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingURL:self.cacheFile error:&error];
    if (fileHandle == nil) {
        NSLog(@"CCTManager: Can't open file %@ for reading: %@", self.cacheFile, error);
        return;
    }

    // Truncate the file and close the file handle
    if (![fileHandle truncateAtOffset:0 error:&error]) {
        NSLog(@"CCTManager: Can't truncate the file after successful request: %@", error);
    } else {
        NSLog(@"CCTManager: Successfully truncated file after successful response");
    }

    if (![fileHandle closeAndReturnError:&error]) {
        NSLog(@"CCTManager: Can't close file: %@", error);
    }
}

- (void)closeConnection {
    // If no connection is currently open, we'll can ignore this method call
    if (self.nw_inbound_connection == NULL) {
        return;
    }

    // If a connection is currently open, we'll send a message to close it
    nw_connection_send(self.nw_inbound_connection, NULL, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true,
            ^(nw_error_t _Nullable error) {
            });

    // And reset the internal state
    self.nw_inbound_connection = NULL;
}


- (void)close {
    // If the listener is running, stop it
    if (self.nw_listener != NULL) {
        nw_listener_cancel(self.nw_listener);
    }
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
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(void) {
            // Print the capture data to the syslog
            NSLog(@"CCTManager: queue = %@", data);
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
        NSLog(@"CCTManager: Unable to convert data to JSON: %@\n%@", error, data);
        return @"";
    }

    // Convert the binary JSON data into a NSString
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    // and remove the 'kCTLCellMonitor' prefix to save space
    return [jsonString stringByReplacingOccurrencesOfString:@"kCTCellMonitor" withString:@""];
}

- (NSURL *)cacheFile {
    NSError *error = nil;

    // Store the temporary file at CaptureCellsTweak/cells-cache.json
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // https://developer.apple.com/forums/thread/688387
    NSURL *tmpDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                                     appropriateForURL:nil create:true error:&error];
    NSURL *tweakDirectory = [tmpDirectory URLByAppendingPathComponent:@"CaptureCellsTweak" isDirectory:true];
    NSURL *cacheFile = [tweakDirectory URLByAppendingPathComponent:@"cells-cache.json"];

    return cacheFile;
}


- (void)writeData:(NSString *)dataString {
    NSError *error = NULL;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *cacheFile = self.cacheFile;

    // Create the directory & file if they both do not exist
    // It's important to use .path insteadof .absoluteString for NSUrl (https://stackoverflow.com/a/8082770)
    if (![fileManager fileExistsAtPath:cacheFile.path]) {
        NSURL *tmpDirectory = [cacheFile URLByDeletingLastPathComponent];

        if (![fileManager createDirectoryAtPath:tmpDirectory.path
                    withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"CCTManager: Can't create temporary directory %@: %@", tmpDirectory.path, error);
            return;
        }
        if (![fileManager createFileAtPath:cacheFile.path contents:[NSData data] attributes:nil]) {
            NSLog(@"CCTManager: Can't create temporary file %@. Does it already exists?", cacheFile.path);
            return;
        }
        NSLog(@"CCTManager: Successfully created empty cache file %@", cacheFile.path);
    }

    // Open the file handle for reading & writing (as we have to skip to the end of the file)
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingURL:cacheFile error:&error];
    if (fileHandle == NULL) {
        NSLog(@"CCTManager: Can't get file handle for %@: %@", cacheFile, error);
        return;
    }

    // Seek to the end of the file (inspired by https://stackoverflow.com/a/11106678)
    unsigned long long int endOffset = 0;
    if (![fileHandle seekToEndReturningOffset:&endOffset error:&error]) {
        NSLog(@"CCTManager: Error when opening file: %@", error);
        return;
    }

    // If the file is larger than 512 MB, we'll truncate it to half of its size
    if (endOffset > 1024 * 1024 * 512) {
        NSLog(@"CCTManager: File end offset (before write) is %lld, truncating file to half of this size", endOffset);

        // Move the file pointer to the middle of the file
        if (![fileHandle seekToOffset:endOffset / 2 error:&error]) {
            NSLog(@"CCTManager: Can't move the file pointer to %lld: %@", endOffset / 2, error);
            return;
        }

        // Read the data until the file end is reached
        NSData *secondFileHalf = [fileHandle readDataToEndOfFileAndReturnError:&error];
        if (secondFileHalf == nil) {
            NSLog(@"CCTManager: Can't read the data of the file until end: %@", error);
            return;
        }

        // Remove all the file blocks on disk
        if (![fileHandle truncateAtOffset:0 error:&error]) {
            NSLog(@"CCTManager: Can't truncate the file: %@", error);
            return;
        }

        // Copy the second half of the old file into the new one
        if (![fileHandle writeData:secondFileHalf error:&error]) {
            NSLog(@"CCTManager: Can't write the second half back to the file: %@", error);
            return;
        }
    }

    // Append a newline and write the JSON data at the end of the file (https://stackoverflow.com/a/901379)
    dataString = [dataString stringByAppendingString:@"\n"];
    [fileHandle writeData:[dataString dataUsingEncoding:NSUTF8StringEncoding] error:&error];

    // Close the file handle
    [fileHandle closeAndReturnError:&error];
}


@end