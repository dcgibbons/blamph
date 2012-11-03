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

+ (NSString *)formatElapsedTime:(NSTimeInterval)elapsedTime
{
    NSString *s = @"       - ";
    if (elapsedTime < 60)
    {
        NSString *hoursStr = @"     ";
        NSUInteger hours = elapsedTime / 3600;
        if (hours > 0)
        {
            hoursStr = [NSString stringWithFormat:@"%3luh ", hours];
            elapsedTime -= 3600 * hours;
        }
        
        NSUInteger minutes = elapsedTime / 60;
        NSString *minutesStr = (minutes < 10) ? @" " : [NSString stringWithFormat:@"%lum", minutes];
        
        s = [NSString stringWithFormat:@"%@%@", hoursStr, minutesStr];
    }
    
    DLog("elapsedTime=%@", s);
    return s;
}

+ (NSString *)formatEventTime:(NSDate *)dateTime
{
    CFLocaleRef currentLocale = CFLocaleCopyCurrent();
    
    CFDateFormatterRef dateFormatter = CFDateFormatterCreate(NULL, currentLocale, kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
    
    CFStringRef formattedString = CFDateFormatterCreateStringWithDate(NULL, dateFormatter, (__bridge CFDateRef)dateTime);
    CFShow(formattedString);
    
    NSDate *now = [NSDate date];
    NSUInteger days = ([dateTime timeIntervalSince1970] -  [now timeIntervalSince1970]) / 86400000L; // milliseconds in a day
    NSString *daysStr = @"    ";
    if (days > 0)
    {
        CFNumberFormatterRef numberFormatter = CFNumberFormatterCreate(NULL, currentLocale, kCFNumberFormatterNoStyle);
        CFStringRef formatString = CFSTR("###+");
        CFNumberFormatterSetFormat(numberFormatter, formatString);
        CFStringRef formattedNumberString = CFNumberFormatterCreateStringWithValue(NULL, numberFormatter, kCFNumberLongType,
                                                                                   &days);
        daysStr = (__bridge NSString *)formattedNumberString;
    }
    
    NSString *s = [NSString stringWithFormat:@"%@%@", daysStr, formattedString];
    
    DLog(@"eventTime=%@", s);
    return s;
}

@end
