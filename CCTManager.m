//
// Created by Lukas Arnold on 31.12.22.
//

#import "CCTManager.h"


@interface CCTManager ()

- (NSURL *)cacheFile;

- (void)handleInboundConnection:(nw_connection_t)connection;

- (void)sendLoop:(NSFileHandle *)fileHandle;

- (void)closeConnection;

- (NSString *)dataToJSON:(NSArray *)data timestamp:(NSTimeInterval)timestamp;

- (void)writeData:(NSString *)data;

@end

@implementation CCTManager {

}

- (instancetype)init {
    self = [super init];
    if (self) {
        // TODO: Is this even required?
        /* self.cellLastData = NULL;
        self.cellLastTimestamp = 0; */
    }

    return self;
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

    NSURL *cacheFile = self.cacheFile;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Close the connection as the cache file is empty
    if (![fileManager fileExistsAtPath:cacheFile.path]) {
        [self closeConnection];
        return;
    }

    NSError *fileError;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:cacheFile error:&fileError];
    if (fileHandle == nil) {
        NSLog(@"Can't open file %@ for reading: %@", cacheFile, fileError);
        return;
    }

    [self sendLoop:fileHandle];
}

- (void)sendLoop:(NSFileHandle *)fileHandle {
    // If no inbound connection is available, there's nothing to do
    if (self.nw_inbound_connection == NULL) {
        return;
    }

    // Get the file descriptor and the queue
    int fileDescriptor = [fileHandle fileDescriptor];
    dispatch_queue_main_t queue = dispatch_get_main_queue();

    // Read 512kb using the dispatch queue from the file descriptor and send it over the wire
    dispatch_read(fileDescriptor, 1024 * 512, queue, ^(dispatch_data_t _Nonnull read_data, int read_error) {
        if (read_error != 0) {
            // If there's an error, we'll log it
            NSLog(@"CCTManager: Can't read from file handle: %d", read_error);

            // Close the connection
            [self closeConnection];

            // Close the fila handle
            NSError *fileError;
            if (![fileHandle closeAndReturnError:&fileError]) {
                NSLog(@"CCTManager: Can't close file handle for reading (with other error): %@", fileError);
            }
        } else if (read_data == NULL) {
            // If the read_data == NULL, the EOF is reached, and we'll send a message to close the connection
            [self closeConnection];

            // Truncate the file and close the file handle
            NSError *fileError;
            if (![fileHandle truncateAtOffset:0 error:&fileError]) {
                NSLog(@"CCTManager: Can't truncate the file after successful request: %@", fileError);
            } else {
                NSLog(@"CCTManger: Successfully truncated file after extraction");
            }

            if (![fileHandle closeAndReturnError:&fileError]) {
                NSLog(@"CCTManager: Can't close file handle for reading: %@", fileError);
            }
        } else {
            nw_connection_send(self.nw_inbound_connection, read_data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
                    ^(nw_error_t _Nullable error) {
                        if (error != NULL) {
                            NSLog(@"CCTManager: Can't send data over the wire: %@", error);
                        } else {
                            [self sendLoop:fileHandle];
                        }
                    });
        }
    });
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

/*
(
    {
        kCTCellMonitorBandInfo = 20;
        kCTCellMonitorBandwidth = 50;
        kCTCellMonitorCellId = 12941827;
        kCTCellMonitorCellRadioAccessTechnology = kCTCellMonitorRadioAccessTechnologyLTE;
        kCTCellMonitorCellType = kCTCellMonitorCellTypeServing;
        kCTCellMonitorDeploymentType = 5;
        kCTCellMonitorMCC = 262;
        kCTCellMonitorMNC = 2;
        kCTCellMonitorPID = 33;
        kCTCellMonitorRSRP = 0;
        kCTCellMonitorRSRQ = 0;
        kCTCellMonitorSectorLat = 0;
        kCTCellMonitorSectorLong = 0;
        kCTCellMonitorTAC = 45711;
        kCTCellMonitorUARFCN = 6300;
    },
    {
        kCTCellMonitorCellRadioAccessTechnology = kCTCellMonitorRadioAccessTechnologyNR;
        kCTCellMonitorCellType = kCTCellMonitorCellTypeNeighbor;
        kCTCellMonitorIsSA = 0;
        kCTCellMonitorNRARFCN = 372750;
        kCTCellMonitorPCI = 133;
        kCTCellMonitorSCS = 0;
    }
)
    // https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32
    // Symbols from /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)

*/

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
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:cacheFile.path];

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