//
//  NSString+StringUtils.m
//  Blamph
//
//  Created by Chad Gibbons on 11/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "NSString+StringUtils.h"

@implementation NSString (StringUtils)

- (NSArray *)smartSplitByLength:(NSUInteger)length
{
    NSString *text = self;
    NSMutableArray *splits = [NSMutableArray arrayWithCapacity:5];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    do
    {
        NSString *current = nil;

        if ([text length] > length)
        {
            current = [text substringToIndex:length];
            NSRange range = [current rangeOfCharacterFromSet:whitespace
                                                     options:NSBackwardsSearch];
            
            if (range.location != NSNotFound)
            {
                current = [current substringToIndex:range.location];
            }
            text = [text substringFromIndex:[current length]];
        }
        else
        {
            current = text;
            text = @"";
        }
        
        [splits addObject:[current stringByTrimmingCharactersInSet:whitespace]];
    } while ([text length] > 0);
    
    return splits;
}

@end
