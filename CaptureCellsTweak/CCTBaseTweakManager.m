//
// Created by Lukas Arnold on 07.06.23.
//

#import "CCTBaseTweakManager.h"

@interface CCTBaseTweakManager ()

- (void)handleInboundConnection:(nw_connection_t)connection;

- (NSURL *)cacheFile;

- (void)emptyCache;

- (void)closeConnection;

@property NSString *tweakName;
@property NSString *cacheFileName;
@property NSString *logPrefix;
@property nw_listener_t nw_listener;
@property nw_connection_t nw_inbound_connection;

@end

@implementation CCTBaseTweakManager {

}

- (instancetype)initWithQueue:(NSString *)queueName :(NSString *)logPrefix :(NSString *)tweakName :(NSString *)cacheFileName {
    self.tweakName = tweakName;
    self.cacheFileName = cacheFileName;
    self.logPrefix = logPrefix;
    self.writeQueue = dispatch_queue_create_with_target(
            queueName.UTF8String, DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    );
    return self;
}

- (void)log:(NSString *)format, ... {
    NSMutableString *s = [NSMutableString stringWithString:self.logPrefix];
    [s appendString:@": "];

    va_list args;
    va_start(args, format);
    [s appendString:[[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);

    NSLog(@"%@", s);
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
        [self log:@"Can't create a TCP listener on port %d", port];
        return;
    }

    // If callback functions are called using the specified the writeQueue
    nw_listener_set_queue(self.nw_listener, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    // Function to handle state changes
    nw_listener_set_state_changed_handler(self.nw_listener, ^(nw_listener_state_t state, nw_error_t error) {
        [self log:@"Network state changed %u - %@", state, error];
    });
    // Function to handle new connection
    nw_listener_set_new_connection_handler(self.nw_listener, ^(nw_connection_t connection) {
        [self handleInboundConnection:connection];
    });

    // Start the listener
    nw_listener_start(self.nw_listener);

    [self log:@"Opened port %d", port];
}

- (void)handleInboundConnection:(nw_connection_t)connection {
    [self log:@"New connection %@", connection];

    // If there's already an open connection, we'll cancel the incoming one
    if (self.nw_inbound_connection != NULL) {
        nw_connection_cancel(connection);
        return;
    }

    // Store the connection and assign it a writeQueue
    self.nw_inbound_connection = connection;
    nw_connection_set_queue(self.nw_inbound_connection, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    nw_connection_set_state_changed_handler(self.nw_inbound_connection, ^(nw_connection_state_t state, nw_error_t error) {
        [self log:@"Connection State Changed %@: %d %@", connection, state, error];
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

    // Read the content of the file using an input stream to limit the memory usage, but do it synchronously to lock the file as short as possible
    // How to use NSInputStream: https://stackoverflow.com/a/6688111
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:cacheFile.path];

    // We must open the input stream as we're reading a file
    [inputStream open];

    // bufferLength can be any positive integer
    NSUInteger bufferLength = 1024 * 8;
    uint8_t buffer[bufferLength];

    NSInteger result;
    NSInteger counter = 0;
    while ((result = [inputStream read:buffer maxLength:bufferLength]) != 0) {
        if (result > 0) {
            // The buffer contains the result bytes of data to be handled

            // Convert the data read from our buffer into dispatch_data_t
            dispatch_data_t sendData = dispatch_data_create(buffer, (size_t) result, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);

            // Send the data (but don't mark the stream as finished)
            // We're marking every 10th message as finished, so that occasionally messages are transmitted
            nw_connection_send(self.nw_inbound_connection, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,
                    counter % 10 == 0, ^(nw_error_t _Nullable error) {
                        if (error != NULL) {
                            // Print an error
                            [self log:@"Can't send data over the wire (data): %@", error];
                        }
                    });
            // [self log:@"Sending data of the size %ld", (long) result];
            counter += 1;
        } else {
            // If the stream had an error, we print it and abort the stream
            [self log:@"Can't read the file %@: %@", cacheFile.path, [inputStream streamError]];
            [self closeConnection];
        }
    }

    // Mark the sending process as complete
    [self log:@"Sending final message after sending %d data messages", counter];

    // Mark the sending process as complete
    nw_connection_send(self.nw_inbound_connection, NULL, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true,
            ^(nw_error_t _Nullable error) {
                if (error != NULL) {
                    // Print an error
                    [self log:@"Can't send data over the wire (final message): %@", error];
                } else {
                    // If everything was successful, clear the cache file
                    [self emptyCache];
                }

                // Close the connection
                nw_connection_cancel(self.nw_inbound_connection);

                // In any case, close the connection
                self.nw_inbound_connection = NULL;
            });
}

- (void)emptyCache {
    // Get a file handle for the cache file
    NSError *error;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingURL:self.cacheFile error:&error];
    if (fileHandle == nil) {
        [self log:@"Can't open file %@ for reading: %@", self.cacheFile, error];
        return;
    }

    // Truncate the file and close the file handle
    if (![fileHandle truncateAtOffset:0 error:&error]) {
        [self log:@"Can't truncate the file after successful request: %@", error];
    } else {
        [self log:@"Successfully truncated file after successful response"];
    }

    if (![fileHandle closeAndReturnError:&error]) {
        [self log:@"Can't close file: %@", error];
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

- (NSURL *)cacheFile {
    NSError *error = nil;

    // Store the temporary file at CapturePacketsTweak/packets-cache.json
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // https://developer.apple.com/forums/thread/688387
    NSURL *tmpDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                                     appropriateForURL:nil create:true error:&error];
    NSURL *tweakDirectory = [tmpDirectory URLByAppendingPathComponent:self.tweakName isDirectory:true];
    NSURL *cacheFile = [tweakDirectory URLByAppendingPathComponent:self.cacheFileName];

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
            [self log:@"Can't create temporary directory %@: %@", tmpDirectory.path, error];
            return;
        }
        if (![fileManager createFileAtPath:cacheFile.path contents:[NSData data] attributes:nil]) {
            [self log:@"Can't create temporary file %@. Does it already exists?", cacheFile.path];
            return;
        }
        [self log:@"Successfully created empty cache file %@", cacheFile.path];
    }

    // Open the file handle for reading & writing (as we have to skip to the end of the file)
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingURL:cacheFile error:&error];
    if (fileHandle == NULL) {
        [self log:@"Can't get file handle for %@: %@", cacheFile, error];
        return;
    }

    // Seek to the end of the file (inspired by https://stackoverflow.com/a/11106678)
    unsigned long long int endOffset = 0;
    if (![fileHandle seekToEndReturningOffset:&endOffset error:&error]) {
        [self log:@"Error when opening file: %@", error];
        return;
    }

    // If the file is larger than 128 MB, we'll truncate it to half of its size
    if (endOffset > 1024 * 1024 * 128) {
        [self log:@"File end offset (before write) is %lld, truncating file to half of this size", endOffset];

        // Move the file pointer to the middle of the file
        if (![fileHandle seekToOffset:endOffset / 2 error:&error]) {
            [self log:@"Can't move the file pointer to %lld: %@", endOffset / 2, error];
            return;
        }

        // Read the data until the file end is reached
        NSData *secondFileHalf = [fileHandle readDataToEndOfFileAndReturnError:&error];
        if (secondFileHalf == nil) {
            [self log:@"Can't read the data of the file until end: %@", error];
            return;
        }

        // Search for the position of the first newline in the new data character
        NSData *newLine = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
        NSRange searchRange = NSMakeRange(0, [secondFileHalf length]);
        NSRange foundRange = [secondFileHalf rangeOfData:newLine options:0 range:searchRange];

        // Cut the incomplete line from the beginning of the string
        if (foundRange.length > 0) {
            NSUInteger newLineOffset = foundRange.location + foundRange.length;
            NSRange fullLineRange = NSMakeRange(newLineOffset, [secondFileHalf length] - newLineOffset);
            [self log:@"Remaining file bytes after truncation: %@", NSStringFromRange(fullLineRange)];
            secondFileHalf = [secondFileHalf subdataWithRange:fullLineRange];
        }

        // Remove all the file blocks on disk
        if (![fileHandle truncateAtOffset:0 error:&error]) {
            [self log:@"Can't truncate the file: %@", error];
            return;
        }

        // Copy the second half of the old file into the new one
        if (![fileHandle writeData:secondFileHalf error:&error]) {
            [self log:@"Can't write the second half back to the file: %@", error];
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
