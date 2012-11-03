//
//  DateTimeUtils.h
//  Blamph
//
//  Created by Chad Gibbons on 11/2/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DateTimeUtils : NSObject

+ (NSString *)formatElapsedTime:(NSTimeInterval)elapsedTime;
+ (NSString *)formatEventTime:(NSDate *)dateTime;

@end
