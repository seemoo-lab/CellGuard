//
// Created by Lukas Arnold on 31.12.22.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>


@interface CCTManager : NSObject

@property nw_listener_t nw_listener;
@property nw_connection_t nw_inbound_connection;

@property NSTimeInterval cellLastTimestamp;
@property NSArray *cellLastData;

- (void)listen:(int)port;

- (void)close;

- (void)addData:(NSArray *)data;


@end