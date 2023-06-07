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
#import "CPTManager.h"

CPTManager* cptManager;

// https://theos.dev/docs/logos-syntax#hookf

%group QMI
// Source: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/tree/main/agent

// libATCommandStudioDynamic.dylib
// QMux::State::handleReadData(unsigned char const*, unsigned int)
// Handles all incoming QMI packets

%hookf(int, HandleReadData, void *instance, unsigned char *data, unsigned int length) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];
	// NSLog(@"Hey, we're hooking QMI read stuff %@", objData);
	[cptManager addData:objData :@"QMI" :@"IN"];

	// Call the original implementation of this function
	return %orig;
}

// libPCITransport.dylib
// pci::transport::th::writeAsync(unsigned char const*, unsigned int, void (*)(void*))
// Handles all outgoing QMI packets

%hookf(int, WriteAsync, void *instance, unsigned char *data, unsigned int length, void *callback) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];
	// NSLog(@"Hey, we're hooking QMI send stuff %@", objData);
	[cptManager addData:objData :@"QMI" :@"OUT"];

	// Call the original implementation of this function
	return %orig;
}

%end

%group ARI
// Source: https://github.com/seemoo-lab/aristoteles/blob/master/tools/frida_ari_functions.js

// libARIServer.dylib
// AriHostRt::InboundMsgCB(unsigned char*, unsigned long)
// Handles all incoming ARI packets

%hookf(int, InboundMsgCB, unsigned char *data, unsigned int length) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];
	// NSLog(@"Hey, we're hooking ARI read stuff %@", objData);
	[cptManager addData:objData :@"ARI" :@"IN"];

	// Call the original implementation of this function
	return %orig;
}

// libPCITransport.dylib
// AriHostRt::sendRawInternal_nl(unsigned char*, unsigned int)
// Handles all outgoing ARI packets
%hookf(int, SendRawInternal, void *instance, unsigned char *data, unsigned int length) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];
	// NSLog(@"Hey, we're hooking ARI send stuff %@", objData);
	[cptManager addData:objData :@"ARI" :@"OUT"];

	// Call the original implementation of this function
	return %orig;
}

%end

%ctor {
	NSString* programName = [NSString stringWithUTF8String: argv[0]];
	if ([programName isEqualToString:@"/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter"]) {
		// Only enable the tweak for the process CommCenter
		NSLog(@"Happy hooking from the CapturePackets tweak in %@", programName);
		cptManager = [CPTManager manager];

		// Collect the references to the two libraries to increase the speed of function finding
		// See: https://github.com/theos/logos/issues/67#issuecomment-682242010
		// See: http://www.cydiasubstrate.com/api/c/MSGetImageByName/
		MSImageRef libATCommandStudioDynamicImage = MSGetImageByName("/usr/lib/libATCommandStudioDynamic.dylib");
		MSImageRef libPCITransportImage = MSGetImageByName("/usr/lib/libPCITransport.dylib");
		MSImageRef libARIServerImage = MSGetImageByName("/usr/lib/libARIServer.dylib");

		// The two underscores in front of the function names are important for MSFindSymbol to work
		// See: http://www.cydiasubstrate.com/api/c/MSFindSymbol/
		if (libARIServerImage == NULL) {
			// The iPhone contains a baseband from Qualcomm
			%init(QMI, 
				HandleReadData = MSFindSymbol(libATCommandStudioDynamicImage, "__ZN4QMux5State14handleReadDataEPKhj"),
				WriteAsync = MSFindSymbol(libPCITransportImage, "__ZN3pci9transport2th10writeAsyncEPKhjPFvPvE")
			);
			NSLog(@"Our CapturePackets tweak hooks QMI packets");
		} else {
			// The iPhone contains a baseband from formely Intel
			%init(ARI, 
				InboundMsgCB = MSFindSymbol(libARIServerImage, "__ZN9AriHostRt12InboundMsgCBEPhm"),
				SendRawInternal = MSFindSymbol(libARIServerImage, "__ZN9AriHostRt18sendRawInternal_nlEPhj")
			);
			NSLog(@"Our CapturePackets tweak hooks QMI packets");
		}

		[cptManager listen:33067];
	}
}

%dtor {
	if (cptManager != NULL) {
		[cptManager close];
	}
}