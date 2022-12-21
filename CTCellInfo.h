// Headers generated with ktool v1.4.0
// https://github.com/cxnder/ktool | pip3 install k2l
// Platform: IOS | Minimum OS: 16.0.0 | SDK: 16.0.0

// Source: https://headers.cynder.me/index.php?sdk=ios/16.0&fw=Frameworks/CoreTelephony.framework&file=Headers/CTCellInfo.h


#ifndef CTCELLINFO_H
#define CTCELLINFO_H

@class NSArray;

#import <Foundation/Foundation.h>

#import "NSCopying-Protocol.h"
#import "NSSecureCoding-Protocol.h"

@interface CTCellInfo : NSObject <NSCopying, NSSecureCoding>



@property (retain, nonatomic) NSArray *legacyInfo; // ivar: _legacyInfo


+(BOOL)supportsSecureCoding;
-(id)copyWithZone:(struct _NSZone *)arg0 ;
-(id)description;
-(id)initWithCoder:(id)arg0 ;
-(void)encodeWithCoder:(id)arg0 ;


@end


#endif