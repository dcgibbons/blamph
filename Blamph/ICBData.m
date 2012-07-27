//
//  ICBData.m
//  Blamph
//
//  Created by Chad Gibbons on 7/9/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ICBData.h"

@implementation ICBData

@synthesize nickname = _nickname;
@synthesize password = _password;
@synthesize serverAddress = _serverAddress;
@synthesize serverPort = _serverPort;
@synthesize groups = _groups;
@synthesize users = _users;
@synthesize messages = _messages;

// TODO: why not store messages in iCloud, and let users retrieve previous uses with 'Load more history' etc.

@end
