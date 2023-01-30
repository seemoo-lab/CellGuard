#import <Foundation/Foundation.h>
#import "CCTManager.h"

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

Documentation: https://theos.dev/docs/logos-syntax
*/

CCTManager* cctManager;

// A group that explicitly must be initialized which is only done for the CommCenter process
%group CommCenter 
%hook CTCellInfo

- (NSArray *)legacyInfo {
	// %log;
	
	// Call the original implementation and get the array
	NSArray * data = %orig;

	// Only if the array is not null, we'll call our manager
	if (data != NULL && cctManager != NULL) {
		[cctManager addData:data];
	}

	// In any case, we'll return the array value
	return data;
}

%end
%end

%ctor {
	// Affected processes: symptomsd, WirelessRadioManagerd, bluetoothd, CommCenter, nearbyd, locationd, and some other helpers
	NSString* programName = [NSString stringWithUTF8String: argv[0]];
	if ([programName isEqualToString:@"/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter"]) {
		NSLog(@"Hello from the capture cells tweak %@", programName);
		cctManager = [[CCTManager alloc] init];
		// Only enable the tweak for the process CommCenter
		%init(CommCenter)
		[cctManager listen:33066];
	}
}

%dtor {
	// NSLog(@"Bye from tweak");
	if (cctManager != NULL) {
		[cctManager close];
	}
}