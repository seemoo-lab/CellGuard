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

%group QMI

// libATCommandStudioDynamic.dylib
// QMux::State::handleReadData(unsigned char const*, unsigned int)
// Handles all incoming QMI packets
// int *_ZN4QMux5State14handleReadDataEPKhj(void *instance, unsigned char *data, unsigned int length);

%hookf(int, HandleReadData, void *instance, unsigned char *data, unsigned int length) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];

	// TODO: Store data + timestmap
	NSLog(@"Hey, we're hooking read stuff %@", objData);

	// Call the original implementation of this function
	return %orig;
}

// libPCITransport.dylib
// pci::transport::th::writeAsync(unsigned char const*, unsigned int, void (*)(void*))
// Handles all outgoing QMI packets
// bool *_ZN3pci9transport2th10writeAsyncEPKhjPFvPvE(void *instance, unsigned char *data, unsigned int length, void *callback);

%hookf(int, WriteAsync, void *instance, unsigned char *data, unsigned int length, void *callback) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];

	// TODO: Store data + timestmap
	NSLog(@"Hey, we're hooking send stuff %@", objData);

	// Call the original implementation of this function
	return %orig;
}

%end

%ctor {
	NSString* programName = [NSString stringWithUTF8String: argv[0]];
	if ([programName isEqualToString:@"/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter"]) {
		// Only enable the tweak for the process CommCenter
		NSLog(@"Happy hooking from the capture QMI tweak in %@", programName);

		// Collect the references to the two libraries to increase the speed of function finding
		// See: https://github.com/theos/logos/issues/67#issuecomment-682242010
		// See: http://www.cydiasubstrate.com/api/c/MSGetImageByName/
		MSImageRef libATCommandStudioDynamicImage = MSGetImageByName("/usr/lib/libATCommandStudioDynamic.dylib");
		MSImageRef libPCITransportImage = MSGetImageByName("/usr/lib/libPCITransport.dylib");

		// The two underscores in front of the function names are important for MSFindSymbol to work
		// See: http://www.cydiasubstrate.com/api/c/MSFindSymbol/
		%init(QMI, 
			HandleReadData = MSFindSymbol(libATCommandStudioDynamicImage, "__ZN4QMux5State14handleReadDataEPKhj"),
			WriteAsync = MSFindSymbol(libPCITransportImage, "__ZN3pci9transport2th10writeAsyncEPKhjPFvPvE")
		);
	}
}