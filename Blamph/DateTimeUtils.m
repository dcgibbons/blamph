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
//    if (elapsedTime < 60) {
//        buffer.append("       - ");
//    } else {
//        long hours = elapsedTime / 3600;
//        if (hours > 0) {
//            NumberFormat nf = NumberFormat.getNumberInstance();
//            FieldPosition fp = new FieldPosition(NumberFormat.INTEGER_FIELD);
//            nf.setMaximumIntegerDigits(3);
//            String h = nf.format(hours, new StringBuffer(), fp).toString();
//            buffer.append(StringUtils.repeatString(" ", 3 - fp.getEndIndex()))
//            .append(h)
//            .append("h ");
//            elapsedTime -= 3600 * hours;
//        } else {
//            buffer.append("     ");
//        }
//        
//        long minutes = elapsedTime / 60;
//        if (minutes < 10) {
//            buffer.append(' ');
//        }
//        buffer.append(minutes).append("m");
//    }
//    
//    return buffer.toString();
    
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
    
    DLog("elapsedTime=%@", s);
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
        DLog(@"padding=%lu", pad);
        dateStr = [NSString stringWithFormat:@"%@%@", [@"" stringByPaddingToLength:pad withString:@" " startingAtIndex:0], dateStr];
    }
    
    NSDate *now = [NSDate date];
    NSUInteger days = ([now timeIntervalSince1970] - [dateTime timeIntervalSince1970]) / 86400.0; // seconds in a day
    DLog(@"now=%f event=%f days=%lu", [now timeIntervalSince1970], [dateTime timeIntervalSince1970], days);
    NSString *daysStr = @"    ";
    if (days > 0)
    {
        daysStr = [NSString stringWithFormat:@"%3lu+", days];
    }
    
    NSString *s = [NSString stringWithFormat:@"%@%@", daysStr, dateStr];
    
    return s;
}

@end
