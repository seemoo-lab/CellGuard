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

#import <Foundation/Foundation.h>

// https://theos.dev/docs/logos-syntax#hookf

// TODO: Introduce the function a bit more
// QMux::State::handleReadData(unsigned char const*, unsigned int)
int *_ZN4QMux5State14handleReadDataEPKhj(void *pointer, unsigned char *data, uint length);

%hookf(int, _ZN4QMux5State14handleReadDataEPKhj, void *pointer, unsigned char *data, uint length) {
	// TODO: Check if we can read the data (using the length) and print it
	NSLog(@"Hey, we're hooking stuff");
	return %orig; // Call the original implementation of this function
}
