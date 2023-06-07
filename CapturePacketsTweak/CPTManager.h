//
// Created by Lukas Arnold on 05.06.23.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>


@interface CPTManager : NSObject

@property nw_listener_t nw_listener;
@property nw_connection_t nw_inbound_connection;

+ (instancetype)managerWithQueue;

- (void)listen:(int)port;

- (void)close;

- (void)addData:(NSData *)packetData :(NSString *)proto :(NSString *)direction;


@end