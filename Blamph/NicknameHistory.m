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
    _history = [[NSMutableArray alloc] init];
    _currentHistory = 0;
}

- (void)remove:(NSString *)nickname
{
    NSUInteger i = [_history indexOfObject:nickname];
    if (i != NSNotFound)
    {
        [_history removeObjectAtIndex:i];
        
        if (_currentHistory == i)
        {
            _currentHistory++;
            if (_currentHistory == [_history count])
            {
                _currentHistory = 0;
            }
        }
    }
}

- (void)add:(NSString *)nickname
{
    for (NSUInteger i = 0, n = [_history count]; i < n; i++)
    {
        NSString *nick = [_history objectAtIndex:i];
        if ([nick compare:nickname options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            [_history removeObjectAtIndex:i];
            break;
        }
    }
    
    [_history insertObject:nickname atIndex:0];
    _currentHistory = 0;
}

- (NSString *)next
{
    NSString *nickname = nil;
    @try
    {
        nickname = [_history objectAtIndex:_currentHistory];
        _currentHistory++;
        if (_currentHistory == [_history count])
        {
            _currentHistory = 0;
        }
    }
    @catch (NSException *exception) {
        _currentHistory = 0;
    }

    return nickname;
}

@end
