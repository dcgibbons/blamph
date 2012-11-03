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
    return [NSArray arrayWithObjects:
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"beep", @"command",
             @"b", @"alias",
             @"GenericCommand", @"class",
             @"beep", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"boot", @"command",
             @"GenericCommand", @"class",
             @"boot", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"cancel", @"command",
             @"GenericCommand", @"class",
             @"cancel", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"cp", @"command",
             @"GenericCommand", @"class",
             @"cp", @"commandName",
             nil],

            [NSDictionary dictionaryWithObjectsAndKeys:
             @"drop", @"command",
             @"d", @"alias",
             @"GenericCommand", @"class",
             @"drop", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"echoback", @"command",
             @"GenericCommand", @"class",
             @"echoback", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"group", @"command",
             @"g", @"alias",
             @"GenericCommand", @"class",
             @"g", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"invite", @"command",
             @"i", @"alias",
             @"GenericCommand", @"class",
             @"invite", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"motd", @"command",
             @"GenericCommand", @"class",
             @"motd", @"commandName",
             nil],

            [NSDictionary dictionaryWithObjectsAndKeys:
             @"nick", @"command",
             @"GenericCommand", @"class",
             @"name", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"pass", @"command",
             @"GenericCommand", @"class",
             @"pass", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"status", @"command",
             @"GenericCommand", @"class",
             @"status", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"topic", @"command",
             @"GenericCommand", @"class",
             @"topic", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"read", @"command",
             @"GenericCommand", @"class",
             @"read", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"write", @"command",
             @"WriteMessageCommand", @"class",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"msg", @"command",
             @"m", @"alias",
             @"MessageCommand", @"class",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"register", @"command",
             @"p", @"alias",
             @"GenericCommand", @"class",
             @"p", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"version", @"command",
             @"v", @"alias",
             @"GenericCommand", @"class",
             @"v", @"commandName",
             nil],
            
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"who", @"command",
             @"w", @"alias",
             @"GenericCommand", @"class",
             @"w", @"commandName",
             nil],
            
            nil];
}

+ (id)commandWithString:(const NSString *)s
{
    if (!commands)
    {
        commands = [ClientCommand createCommands];
    }
    
    const NSArray *args = [s componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    const NSString *cmdName = [args objectAtIndex:0];
    
    __block ClientCommand *command = nil;

    void (^findCommand)(id, NSUInteger, BOOL *) = ^(id obj, NSUInteger idx, BOOL *stop)
    {
        NSDictionary *d = (NSDictionary *)obj;
        
        NSString *commandName = [d objectForKey:@"command"];
        NSString *aliasName = [d objectForKey:@"alias"];
        
        DLog("looking for client command with name of %@ or alias of %@, arg0=%@",
             commandName, aliasName, cmdName);
        if ([cmdName compare:commandName options:NSCaseInsensitiveSearch] == NSOrderedSame ||
            [cmdName compare:aliasName options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            NSString *className = [d objectForKey:@"class"];
            NSString *genericCommandName = [d objectForKey:@"commandName"];
            DLog(@"found command, className=%@", className);
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

    DLog(@"client command=%@", command);
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
    