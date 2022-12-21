#import <Foundation/Foundation.h>

// Generated with '$THEOS/bin/logify.pl ./CTCellInfo.h > Tweak_2.x'

%hook CTCellInfo
// - (void)setLegacyInfo:(NSArray *)legacyInfo { %log; %orig; }
- (NSArray *)legacyInfo { %log; NSArray * r = %orig; NSLog(@" = %@ tweak", r); return r; }
// +(BOOL)supportsSecureCoding { %log; BOOL r = %orig; NSLog(@" = %d tweak", r); return r; }
// -(id)copyWithZone:(struct _NSZone *)arg0  { %log; id r = %orig; NSLog(@" = %@ tweak", r); return r; }
// -(id)description { %log; id r = %orig; NSLog(@" = %@ tweak", r); return r; }
// -(id)initWithCoder:(id)arg0  { %log; id r = %orig; NSLog(@" = %@ tweak", r); return r; }
// -(void)encodeWithCoder:(id)arg0  { %log; %orig; }
%end
