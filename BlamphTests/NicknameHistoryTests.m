//
//  NicknameHistoryTests.m
//  Blamph
//
//  Created by Chad Gibbons on 11/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "NicknameHistoryTests.h"
#import "NicknameHistory.h"

@implementation NicknameHistoryTests

- (void)testNickNameHistory
{
    NicknameHistory *nh = [[NicknameHistory alloc] init];
    STAssertNotNil(nh, @"NicknameHistory could not be created");
    
    NSString *nick = [nh next];
    STAssertNil(nick, @"next nickname should have been empty");
}

- (void)testSingleNickname
{
    NicknameHistory *nh = [[NicknameHistory alloc] init];
    
    [nh add:@"bob"];
    NSString *nick = [nh next];
    STAssertTrue([nick compare:@"bob"] == NSOrderedSame, @"expected nick not found");
    nick = [nh next];
    STAssertTrue([nick compare:@"bob"] == NSOrderedSame, @"expected nick not found");
}

- (void)testMultipleNickname
{
    NicknameHistory *nh = [[NicknameHistory alloc] init];
    
    [nh add:@"bob"];
    [nh add:@"fred"];
    NSString *nick = [nh next];
    STAssertTrue([nick compare:@"fred"] == NSOrderedSame, @"expected nick not found");
    nick = [nh next];
    STAssertTrue([nick compare:@"bob"] == NSOrderedSame, @"expected nick not found");
}

- (void)testRemove
{
    NicknameHistory *nh = [[NicknameHistory alloc] init];

    [nh add:@"bob"];
    [nh add:@"fred"];
    [nh add:@"jane"];
    
    [nh remove:@"fred"];
    NSString *nick = [nh next];
    STAssertTrue([nick compare:@"jane"] == NSOrderedSame, @"expected nick not found");
    nick = [nh next];
    STAssertTrue([nick compare:@"bob"] == NSOrderedSame, @"expected nick not found");
    nick = [nh next];
    STAssertTrue([nick compare:@"jane"] == NSOrderedSame, @"expected nick not found");
}

@end
