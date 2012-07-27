//
//  ServerDefinition.m
//  Blamph
//
//  Created by Chad Gibbons on 7/26/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ServerDefinition.h"

@implementation ServerDefinition

@synthesize name = _name;
@synthesize hostname = _hostname;
@synthesize port = _port;

- (id)initWithName:(NSString *)serverName andHostname:(NSString *)serverHostname andPort:(NSUInteger)serverPort
{
    NSLog(@"ServerDefinition init!");
    if (self = [super init])
    {
        self.name = serverName;
        self.hostname = serverHostname;
        self.port = serverPort;
        NSLog(@"ServerDefinition: init name=%@ hostname=%@ port=%u", self.name, self.hostname, self.port);
    }
    return self;
}
@end
