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

// libATCommandStudioDynamic.dylib
// sLogBinaryToOsLog(os_log_s*, qmi::LogLevel, qmi::MessageType, qmi::ServiceType, unsigned short, qmi::SimSlot, void const*, unsigned long)
// Handles all incoming and outgoing QMI packets

%hookf(void, SLog, void* os_log, int logLevel, unsigned int messageType, unsigned long serviceType, int param1, int simSlot, const void* data, int length) {

	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];

	// messageType 0: "Req", 1: "Resp", 2: "Ind"
	NSString* direction = messageType == 0 ? @"OUT" : @"IN";
	
	// NSLog(@"Hey, we're hooking ARI & QMI send stuff %@", objData);
	[cptManager addData:objData :direction :simSlot];

	return %orig;
}

%end

%group AriIn

// libARIServer.dylib
// AriHostRt::InboundMsgCB(unsigned char*, unsigned long)
// Handles all incoming ARI packets
// Source: https://github.com/seemoo-lab/aristoteles/blob/master/tools/frida_ari_functions.js

%hookf(int, InboundMsgCB, unsigned char *data, unsigned int length) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];
	// NSLog(@"Hey, we're hooking ARI read stuff %@", objData);
	[cptManager addData:objData :@"IN" :0];

	// Call the original implementation of this function
	return %orig;
}

%end

%group AriOut

// libPCITransport.dylib
// pci::transport::th::writeAsync(unsigned char const*, unsigned int, void (*)(void*))
// Handles all outgoing ARI & QMI packets
// Source: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/tree/main/agent

%hookf(int, WriteAsync, void *instance, unsigned char *data, unsigned int length, void *callback) {
	// Copy the data buffer into a NSData object
	// See: https://developer.apple.com/documentation/foundation/nsdata/1547231-datawithbytes?language=objc
	NSData *objData = [NSData dataWithBytes:data length:length];
	// NSLog(@"Hey, we're hooking ARI & QMI send stuff %@", objData);
	[cptManager addData:objData :@"OUT" :0];

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

		// We can always hook this function and on ARI iPhone it is never called.
		%init(QMI, SLog = MSFindSymbol(libATCommandStudioDynamicImage, "__ZL17sLogBinaryToOsLogP8os_log_sN3qmi8LogLevelENS1_11MessageTypeENS1_11ServiceTypeEtNS1_7SimSlotEPKvm"));
		NSLog(@"Our CapturePackets tweak hooks QMI packets");

		// libARIServer is not directly loaded into the CommCenter process.
		// We have to wait a bit for it to be available.
		// The library is only loaded on ARI iPhones.
		// 1s = 10^9s
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			MSImageRef libARIServer = MSGetImageByName("/usr/lib/libARIServer.dylib");
			// Only initialize the hook for incoming ARI messages as the library is only loaded on ARI iPhones.
			if (libARIServer != NULL) {
				%init(AriIn, InboundMsgCB = MSFindSymbol(libARIServer, "__ZN9AriHostRt12InboundMsgCBEPhm"));
				// NSLog(@"libARIServer: %p - InboundMsg: %p", libARIServer, MSFindSymbol(libARIServer, "__ZN9AriHostRt12InboundMsgCBEPhm"));

				// The two underscores in front of the function names are important for MSFindSymbol to work
				// See: http://www.cydiasubstrate.com/api/c/MSFindSymbol/
				%init(AriOut, WriteAsync = MSFindSymbol(libPCITransportImage, "__ZN3pci9transport2th10writeAsyncEPKhjPFvPvE"));

				NSLog(@"Our CapturePackets tweak also hooks ARI packets");
			}
		});


		[cptManager listen:33067];
	}
}

%dtor {
	if (cptManager != NULL) {
		[cptManager close];
	}
}