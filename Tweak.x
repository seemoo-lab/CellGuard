#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <Network/Network.h>

/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave consequences!
%end
*/

// Alternative:
// https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app
// https://developer.apple.com/documentation/backgroundtasks

// https://developer.apple.com/documentation/corelocation/cllocationmanagerdelegate?language=objc
// https://gist.github.com/ccabanero/6570684
// https://stackoverflow.com/questions/4152003/how-can-i-get-current-location-from-user-in-ios
// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/DefiningClasses/DefiningClasses.html

// https://developer.apple.com/documentation/corelocation/handling_location_updates_in_the_background?language=objc
// https://developer.apple.com/documentation/corelocation/cllocationmanager/1620551-requestalwaysauthorization?language=objc
// https://developer.apple.com/forums/thread/685525

NSTimeInterval g_last_update_timestmap = 0;
NSArray *g_last_update_array = NULL;
nw_listener_t g_listener = NULL;
nw_connection_t g_inbound_connection = NULL;

%ctor {
	NSString* programName = [NSString stringWithUTF8String: argv[0]];
	NSLog(@"Hello from tweak %@", programName);
	if ([programName isEqualToString:@"/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter"]) {
		// https://developer.apple.com/documentation/network/implementing_netcat_with_network_framework?language=objc
		nw_parameters_t parameters = nw_parameters_create_secure_tcp(
			NW_PARAMETERS_DISABLE_PROTOCOL,
			NW_PARAMETERS_DEFAULT_CONFIGURATION
		);
		// TODO: Only create for 127.0.0.1 interface with 
		g_listener = nw_listener_create_with_port("33066", parameters);
		nw_listener_set_queue(g_listener, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
		nw_listener_set_state_changed_handler(g_listener, ^(nw_listener_state_t state, nw_error_t error) {
			NSLog(@"tweak: Network state changed %u - %@", state, error);
		});
		nw_listener_set_new_connection_handler(g_listener, ^(nw_connection_t connection) {
			if (g_inbound_connection != NULL) {
				nw_connection_cancel(connection);
			} else {
				g_inbound_connection = connection;
				nw_connection_set_queue(g_inbound_connection, dispatch_get_main_queue());
				nw_connection_set_state_changed_handler(g_inbound_connection, ^(nw_connection_state_t state, nw_error_t error) {
					// TODO: Print anything?
				});
				nw_connection_start(g_inbound_connection);

				NSData *stringNSData = [@"Hello World\n" dataUsingEncoding:NSUTF8StringEncoding];
				Byte bytes[stringNSData.length];
				[stringNSData getBytes:bytes length:stringNSData.length];
				dispatch_data_t sendData = dispatch_data_create(bytes, stringNSData.length, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
				nw_connection_send(g_inbound_connection, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t _Nullable error) {
					if (error != NULL) {
						NSLog(@"tweak: Send Error Log %@", error);
						// … error logging …
					} else {
						nw_connection_send(g_inbound_connection, NULL, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true, ^(nw_error_t _Nullable error) {});
					}
				});
			}

			NSLog(@"tweak: New connection %@", connection);
		});
		nw_listener_start(g_listener);

		NSLog(@"tweak: Opened port 33066");
	}
}

%dtor {
	NSLog(@"Bye from tweak");
	if (g_listener != NULL) {
		nw_listener_cancel(g_listener);
	}

	g_last_update_timestmap = 0;
	g_last_update_array = NULL;

}

%hook CTCellInfo

- (NSArray *)legacyInfo { 
	// %log; 
	
	// Call the original implementation and get the array
	NSArray * r = %orig;

	// If the array points to NULL, we'll just pass it on
	if (r == NULL) {
		return r;
	}

	// If the new array is different or at least a second has passed, we'll log the array
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	if ((now - g_last_update_timestmap) > 1.0 || ![r isEqualToArray: g_last_update_array]) {
		g_last_update_timestmap = now;
		g_last_update_array = [r copy];

		// https://stackoverflow.com/a/17453020
		// https://developer.apple.com/documentation/dispatch?language=objc
		// https://developer.apple.com/documentation/dispatch/1452927-dispatch_get_global_queue
		// https://developer.apple.com/documentation/dispatch/1453057-dispatch_async
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(void) {
			NSLog(@"queue = %@ tweak from queue", r);

			// https://developer.apple.com/documentation/corelocation/clauthorizationstatus/kclauthorizationstatusrestricted?language=objc
		});

		// NSLog(@" = %@ tweak", r);
	}

	/*
	Should we serailize the whole array or just use CSV?
	-> https://stackoverflow.com/a/5523061
	-> https://dmtopolog.com/object-serialization-in-ios/
	-> https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Archiving.html#//apple_ref/doc/uid/10000047i
	
	Yeah, let just use CSV.

	Next question, where to write file and how to link it into the app?

	-> TODO: Write to file where the app can read from
	-> https://developer.apple.com/documentation/foundation/nsfilemanager

	*/ 

	// In any case, we'll return the array value
	return r;
}

%end