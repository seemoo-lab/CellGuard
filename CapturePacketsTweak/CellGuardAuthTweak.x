
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>

// NSString *authKey;

static NSString *const kHBCBPreferencesDomain = @"de.mpass.cellguard";
static NSString *const kHBCBPreferencesEnabledKey = @"Enabled";
static NSString *const kHBCBPreferencesAuthKey = @"authkey";


HBPreferences *preferences;

%ctor {
	preferences = [[HBPreferences alloc] initWithIdentifier:kHBCBPreferencesDomain];
}

%hook TweakAuthManager

- (NSString *)key {
    NSLog(@"HOOKED key called");
    
    bool test = [preferences boolForKey: kHBCBPreferencesEnabledKey];
    NSLog(@"HOOKED mybool: %d", test);

    NSString *authKey = [preferences objectForKey: kHBCBPreferencesAuthKey];
    NSLog(@"HOOKED authkey: %@", authKey);

    return @"Hi";
}

%end
