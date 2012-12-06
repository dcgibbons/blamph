//
//  ClientCommand.m
//  Blamph
//
//  Created by Chad Gibbons on 11/3/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ClientCommand.h"

@implementation ClientCommand

static NSArray *commands = nil;

+ (NSArray *)createCommands
{
    return @[@{@"command": @"beep",
             @"alias": @"b",
             @"class": @"GenericCommand",
             @"commandName": @"beep"},
            
            @{@"command": @"boot",
             @"class": @"GenericCommand",
             @"commandName": @"boot"},
            
            @{@"command": @"cancel",
             @"class": @"GenericCommand",
             @"commandName": @"cancel"},
            
            @{@"command": @"cp",
             @"class": @"GenericCommand",
             @"commandName": @"cp"},
            
            @{@"command": @"drop",
             @"alias": @"d",
             @"class": @"GenericCommand",
             @"commandName": @"drop"},
            
            @{@"command": @"echoback",
             @"class": @"GenericCommand",
             @"commandName": @"echoback"},
            
            @{@"command": @"group",
             @"alias": @"g",
             @"class": @"GenericCommand",
             @"commandName": @"g"},
            
            @{@"command": @"invite",
             @"alias": @"i",
             @"class": @"GenericCommand",
             @"commandName": @"invite"},
            
            @{@"command": @"motd",
             @"class": @"GenericCommand",
             @"commandName": @"motd"},
            
            @{@"command": @"nick",
             @"class": @"GenericCommand",
             @"commandName": @"name"},
            
            @{@"command": @"pass",
             @"class": @"GenericCommand",
             @"commandName": @"pass"},
            
            @{@"command": @"status",
             @"class": @"GenericCommand",
             @"commandName": @"status"},
            
            @{@"command": @"topic",
             @"class": @"GenericCommand",
             @"commandName": @"topic"},
            
            @{@"command": @"read",
             @"class": @"GenericCommand",
             @"commandName": @"read"},
            
            @{@"command": @"write",
             @"class": @"WriteMessageCommand"},
            
            @{@"command": @"msg",
             @"alias": @"m",
             @"class": @"MessageCommand"},
            
            @{@"command": @"register",
             @"alias": @"p",
             @"class": @"GenericCommand",
             @"commandName": @"p"},
            
            @{@"command": @"version",
             @"alias": @"v",
             @"class": @"GenericCommand",
             @"commandName": @"v"},
            
            @{@"command": @"who",
             @"alias": @"w",
             @"class": @"GenericCommand",
             @"commandName": @"w"}];
}

+ (id)commandWithString:(const NSString *)s
{
    if (!commands)
    {
        commands = [ClientCommand createCommands];
    }
    
    const NSArray *args = [s componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    const NSString *cmdName = args[0];
    
    __block ClientCommand *command = nil;

    void (^findCommand)(id, NSUInteger, BOOL *) = ^(id obj, NSUInteger idx, BOOL *stop)
    {
        NSDictionary *d = (NSDictionary *)obj;
        
        NSString *commandName = d[@"command"];
        NSString *aliasName = d[@"alias"];
        
        if ([cmdName compare:commandName options:NSCaseInsensitiveSearch] == NSOrderedSame ||
            [cmdName compare:aliasName options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            NSString *className = d[@"class"];
            NSString *genericCommandName = d[@"commandName"];
            command = [[NSClassFromString(className) alloc] initWithCommandName:genericCommandName
                                                                        andArgs:[args subarrayWithRange:NSMakeRange(1, [args count] - 1)]];
            *stop = TRUE;
        }
        else
        {
            *stop = FALSE;
        }
    };

    [commands enumerateObjectsUsingBlock:findCommand];

    return command;
}

- (id)initWithCommandName:(NSString *)n andArgs:(NSArray *)a
{
    if (self = [super init])
    {
        commandName = n;
        args = a;
    }
    return self;
}

- (void)processCommandWithClient:(ICBClient *)client
{
    // NO-OP
}


@end
    