//
//  NicknameHistory.h
//  Blamph
//
//  Created by Chad Gibbons on 11/19/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NicknameHistory : NSObject
{
@private
    NSMutableArray *history;
    NSUInteger currentHistory;
}

- (void)clear;
- (void)add:(NSString *)nickname;
- (void)remove:(NSString *)nickname;
- (NSString *)next;

@end
