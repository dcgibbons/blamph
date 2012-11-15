//
//  DateTimeUtils.m
//  Blamph
//
//  Created by Chad Gibbons on 11/2/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "Debugkit.h"
#import "DateTimeUtils.h"

@implementation DateTimeUtils

//private String formatTime(long elapsedTime) {
//    Long minutes = new Long(elapsedTime / 60 % 60);
//    Long hours = new Long(elapsedTime / 3600 % 24);
//    Long days = new Long(elapsedTime / 86400);
//    
//    // TODO: would be nice to figure out a way to use ChoiceFormat to
//    // make this i18n compliant
//    StringBuffer buffer = new StringBuffer();
//    if (days.longValue() > 0) {
//        buffer.append(days).append("d ");
//    }
//    if (hours.longValue() > 0 || days.longValue() > 0) {
//        buffer.append(hours).append("h ");
//    }
//    buffer.append(minutes).append('m');
//    
//    return buffer.toString();
//}
//
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
    
    CFDateFormatterRef dateFormatter = CFDateFormatterCreate(NULL, currentLocale, kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
    
    CFStringRef formattedString = CFDateFormatterCreateStringWithDate(NULL, dateFormatter, (__bridge CFDateRef)dateTime);
    NSString *dateStr = (__bridge NSString *)(formattedString);
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
