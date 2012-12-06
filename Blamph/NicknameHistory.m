//
//  NicknameHistory.m
//  Blamph
//
//  Created by Chad Gibbons on 11/19/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "NicknameHistory.h"

@implementation NicknameHistory

- (id)init
{
    if (self = [super init])
    {
        [self clear];
    }
    
    return self;
}

- (void)clear
{
    history = [[NSMutableArray alloc] init];
    currentHistory = 0;
}

- (void)remove:(NSString *)nickname
{
    NSUInteger i = [history indexOfObject:nickname];
    if (i != NSNotFound)
    {
        [history removeObjectAtIndex:i];
        
        if (currentHistory == i)
        {
            currentHistory++;
            if (currentHistory == [history count])
            {
                currentHistory = 0;
            }
        }
    }
}

- (void)add:(NSString *)nickname
{
    for (NSUInteger i = 0, n = [history count]; i < n; i++)
    {
        NSString *nick = history[i];
        if ([nick compare:nickname options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            [history removeObjectAtIndex:i];
            break;
        }
    }
    
    [history insertObject:nickname atIndex:0];
    currentHistory = 0;
}

- (NSString *)next
{
    NSString *nickname = nil;
    @try
    {
        nickname = history[currentHistory];
        currentHistory++;
        if (currentHistory == [history count])
        {
            currentHistory = 0;
        }
    }
    @catch (NSException *exception) {
        currentHistory = 0;
    }

    return nickname;
}

@end
