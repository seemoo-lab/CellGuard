/// <reference path="../frida-gum.d.ts" />

// This Frida script prints the value of the legacyInfo property of the class CTCellInfo at each invocation.

// Explore all methods of the class with:
// frida-trace -U -m '*[CTCellInfo *]'

const { CTCellInfo } = ObjC.classes;

console.log(`Found -[CTCellInfo legacyInfo] at ${CTCellInfo['- legacyInfo'].implementation}`);

Interceptor.attach(CTCellInfo['- legacyInfo'].implementation, {
    onEnter(args) {
        // ObjC: args[0] = self, args[1] = selector, args[2-n] = arguments
        const self = new ObjC.Object(args[0]);
        console.log(`-[CTCellInfo legacyInfo] State: ${self.$ivars['_legacyInfo']}`);
    },
});
