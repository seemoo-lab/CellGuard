#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

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

@interface CaptureCellsLocationDelegate: NSObject<CLLocationManagerDelegate>

@end

@implementation CaptureCellsLocationDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
	NSLog(@" = %@ tweak loc change authorization %d", manager, manager.authorizationStatus);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    NSLog(@" = %@ tweak loc update", locations);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@" = %@ tweak loc error", error);
}

// https://developer.apple.com/documentation/corelocation/handling_location_updates_in_the_background?language=objc
// https://developer.apple.com/documentation/corelocation/cllocationmanager/1620551-requestalwaysauthorization?language=objc
// https://developer.apple.com/forums/thread/685525

// TODO: Initialize the LocationManager here if we've solve the problem

@end

NSTimeInterval lastUpdateTimestmap = 0;
NSArray *lastUpdateArray = NULL;
CLLocationManager* locationManager = NULL;
CaptureCellsLocationDelegate* locationManagerDelegate = NULL;

%ctor {
	NSLog(@"Hello from tweak");
	locationManager = [[CLLocationManager alloc] init];
	locationManagerDelegate = [CaptureCellsLocationDelegate alloc];

	locationManager.distanceFilter = kCLDistanceFilterNone;
	locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	locationManager.delegate = locationManagerDelegate;
}

%dtor {
	NSLog(@"Bye from tweak");
	locationManager = NULL;
	locationManagerDelegate = NULL;
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
	if ((now - lastUpdateTimestmap) > 1.0 || ![r isEqualToArray: lastUpdateArray]) {
		lastUpdateTimestmap = now;
		lastUpdateArray = [r copy];

		// https://stackoverflow.com/a/17453020
		// https://developer.apple.com/documentation/dispatch?language=objc
		// https://developer.apple.com/documentation/dispatch/1452927-dispatch_get_global_queue
		// https://developer.apple.com/documentation/dispatch/1453057-dispatch_async
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(void) {
			NSLog(@"queue = %@ tweak from queue", r);
			// TODO: Move up to init method
			NSLog(@"queue = %@ tweak from queue", r);
			NSLog(@"tweak locman = %@", locationManager);
			NSLog(@"tweak delegate = %@", locationManagerDelegate);

			[locationManager requestLocation];
			// https://developer.apple.com/documentation/corelocation/clauthorizationstatus/kclauthorizationstatusrestricted?language=objc
			NSLog(@"tweak loc status %d == kCLAuthorizationStatusRestricted (%d)", locationManager.authorizationStatus, kCLAuthorizationStatusRestricted);
			// [locationManager startUpdatingLocation];
			// [locationManager stopUpdatingLocation];
		});

		NSLog(@" = %@ tweak", r);
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