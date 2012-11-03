//
//  ClientCommand.h
//  Blamph
//
//  Created by Chad Gibbons on 11/3/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICBClient.h"

@interface ClientCommand : NSObject
{
@protected
    NSArray *args;
    NSString *commandName;
}

+ (id)commandWithString:(NSString *)s;

- (id)initWithCommandName:(NSString *)name andArgs:(NSArray *)args;
- (void)processCommandWithClient:(ICBClient *)client;

@end
