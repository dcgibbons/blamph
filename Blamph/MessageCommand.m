//
//  MessageCommand.m
//  Blamph
//
//  Created by Chad Gibbons on 11/3/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "MessageCommand.h"

@implementation MessageCommand

- (void)processCommandWithClient:(ICBClient *)client
{
    [client sendPersonalMessage:args[0]
                        withMsg:[[args subarrayWithRange:NSMakeRange(1, [args count] - 1)] componentsJoinedByString:@" "]];
}

@end
