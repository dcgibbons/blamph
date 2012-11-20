//
//  GenericCommand.m
//  Blamph
//
//  Created by Chad Gibbons on 11/3/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "GenericCommand.h"
#import "CommandPacket.h"

@implementation GenericCommand

- (void)processCommandWithClient:(ICBClient *)client
{
    CommandPacket *packet = [[CommandPacket alloc] initWithCommand:commandName
                                                      optionalArgs:[args componentsJoinedByString:@" "]];
    [client sendPacket:packet];
}

@end
