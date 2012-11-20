//
//  DateTimeUtils.m
//  Blamph
//
//  Created by Chad Gibbons on 11/2/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "DebugKit.h"
#import "DateTimeUtils.h"

@implementation DateTimeUtils

+ (NSString *)formatSimpleTime:(NSTimeInterval)elapsedTime
{
    NSUInteger minutes = (NSUInteger)elapsedTime / 60 % 60;
    NSUInteger hours = (NSUInteger)elapsedTime / 3600 % 24;
    NSUInteger days = (NSUInteger)elapsedTime / 86400;
    
    NSMutableString *str = [NSMutableString stringWithCapacity:32];
    if (days > 0)
    {
        [str appendFormat:@"%lud ", days];
    }
    if (hours > 0 || days > 0)
    {
        [str appendFormat:@"%luh ", hours];
    }
    [str appendFormat:@"%lum", minutes];
    return [NSString stringWithString:str];
}

+ (NSString *)formatElapsedTime:(NSTimeInterval)elapsedTime
{
    NSString *s = nil;
    if (elapsedTime < 60)
    {
        s = @"       -";
    }
    else
    {
        NSString *hoursStr = @"     ";
        NSUInteger hours = elapsedTime / 3600;
        if (hours > 0)
        {
            hoursStr = [NSString stringWithFormat:@"%3luh ", hours];
            elapsedTime -= 3600 * hours;
        }
        
        NSUInteger minutes = elapsedTime / 60;
        NSString *minutesStr = [NSString stringWithFormat:@"%2lum", minutes];
        
        s = [NSString stringWithFormat:@"%@%@", hoursStr, minutesStr];
    }
    
    return s;
}

+ (NSString *)formatEventTime:(NSDate *)dateTime
{
    CFLocaleRef currentLocale = CFLocaleCopyCurrent();
    CFDateFormatterRef dateFormatter = CFDateFormatterCreate(NULL,
                                                             currentLocale,
                                                             kCFDateFormatterNoStyle,
                                                             kCFDateFormatterShortStyle);
    CFRelease(currentLocale);
    
    CFStringRef formattedString = CFDateFormatterCreateStringWithDate(NULL,
                                                                      dateFormatter,
                                                                      (__bridge CFDateRef)dateTime);
    CFRelease(dateFormatter);

    NSString *dateStr = (__bridge_transfer NSString *)(formattedString);
    NSUInteger pad = 8 - [dateStr length];
    if (pad > 0)
    {
        dateStr = [NSString stringWithFormat:@"%@%@", [@"" stringByPaddingToLength:pad withString:@" " startingAtIndex:0], dateStr];
    }
    
    NSDate *now = [NSDate date];
    NSUInteger days = ([now timeIntervalSince1970] - [dateTime timeIntervalSince1970]) / 86400.0; // seconds in a day
    NSString *daysStr = @"    ";
    if (days > 0)
    {
        daysStr = [NSString stringWithFormat:@"%3lu+", days];
    }
    
    NSString *s = [NSString stringWithFormat:@"%@%@", daysStr, dateStr];
    
    return s;
}

@end
