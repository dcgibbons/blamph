//
//  AppDelegate.m
//  Blamph
//
//  Created by Chad Gibbons on 10/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "ClientCommand.h"
#import "ServerDefinition.h"
#import "DateTimeUtils.h"

@implementation AppDelegate

@synthesize inputTextField;
@synthesize outputTextView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    servers = [NSMutableArray arrayWithObjects:

               [[ServerDefinition alloc] initWithName:@"localhost"
                                          andHostname:@"localhost"
                                              andPort:7326],

               [[ServerDefinition alloc] initWithName:@"default"
                                          andHostname:@"default.icb.net"
                                              andPort:7326],

               nil];
    
    [self.window makeFirstResponder:self.inputTextField];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if (control == self.inputTextField)
    {
        NSString *cmd = self.inputTextField.stringValue;
        [self.inputTextField setStringValue:@""];
        
        if (cmd == nil || [cmd length] == 0)
            return TRUE;
        
        // if the input isn't prefixed with the command character just send
        // the text as an open message
        if ([cmd characterAtIndex:0] != '/')
        {
            [client sendOpenMessage:cmd];
        }
        
        // check if they escaped the / with another and send it as an open
        // message
        else if ([cmd characterAtIndex:1] == '/')
        {
            [client sendOpenMessage:[cmd substringFromIndex:1]];
        }
        
        // otherwise, we've got command! see if a ClientCommand has been
        // defined and process it that way, otherwise send a personal message
        // to the Server for any other processing
        else
        {
            cmd = [cmd substringFromIndex:1];
            ClientCommand *command = [ClientCommand commandWithString:cmd];
            if (!command)
            {
                [client sendPersonalMessage:@"server"
                                    withMsg:cmd];
            }
            else
            {
                [command processCommandWithClient:client];
            }
        }
    }
    
    return YES;
}

- (IBAction)connect:(id)sender
{
    NSString *nickname = @"chadwick2";
    NSUInteger server = 0;
    
    ServerDefinition *serverDefinition = (ServerDefinition *)[servers objectAtIndex:server];
    if (serverDefinition != nil)
    {
        NSLog(@"Ready to connect as user %@ to server %@", nickname, serverDefinition);
        //MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        //hud.labelText = @"Connecting";
        
        client = [[ICBClient alloc] initWithServer:serverDefinition
                                       andNickname:nickname];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePacket:)
                                                     name:@"ICBPacket"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientNotify:)
                                                     name:nil
                                                   object:client];
    }
}

- (IBAction)disconnect:(id)sender
{
    // TODO
}

- (void)handlePacket:(NSNotification *)notification
{
    const ICBPacket *packet = [notification object];
    
    [self displayMessageTimestamp];
    
    if ([packet isKindOfClass:[OpenPacket class]])
    {
        [self displayOpenPacket:(OpenPacket *)packet];
    }
    else if ([packet isKindOfClass:[PersonalPacket class]])
    {
        [self displayPersonalPacket:(PersonalPacket *)packet];
    }
    else if ([packet isKindOfClass:[CommandOutputPacket class]])
    {
        [self displayCommandOutputPacket:(CommandOutputPacket *)packet];
    }
    else if ([packet isKindOfClass:[BeepPacket class]])
    {
        [self displayBeepPacket:(BeepPacket *)packet];
    }
    else if ([packet isKindOfClass:[ExitPacket class]])
    {
        [self displayExitPacket:(ExitPacket *)packet];
    }
    else if ([packet isKindOfClass:[PingPacket class]])
    {
        [self displayPingPacket:(PingPacket *)packet];
    }
    else if ([packet isKindOfClass:[ProtocolPacket class]])
    {
        [self displayProtocolPacket:(ProtocolPacket *)packet];
    }
    else if ([packet isKindOfClass:[ErrorPacket class]])
    {
        [self displayErrorPacket:(ErrorPacket *)packet];
    }
    else if ([packet isKindOfClass:[StatusPacket class]])
    {
        [self displayStatusPacket:(StatusPacket *)packet];
    }
    
    // TODO: don't scroll down if scrolled-back
    NSRange range = NSMakeRange(self.outputTextView.textStorage.length - 1, 1);
    [self.outputTextView scrollRangeToVisible:range];
}

- (void)displayMessageTimestamp
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, now);

    CFLocaleRef currentLocale = CFLocaleCopyCurrent();
    
    CFDateFormatterRef dateFormatter = CFDateFormatterCreate
    (NULL, currentLocale, kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
    
    CFStringRef formattedString = CFDateFormatterCreateStringWithDate(NULL, dateFormatter, date);
    CFShow(formattedString);
    
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"%@ ", formattedString];
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayOpenPacket:(OpenPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"<%@> %@\n", p.nick, p.text];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSLinkAttributeName value:p.nick range:NSMakeRange(1, [p.nick length])];
    
    [textStorage appendAttributedString:as];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayPersonalPacket:(PersonalPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"<*%@*> %@\n", p.nick, p.text];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSLinkAttributeName value:p.nick range:NSMakeRange(2, [p.nick length])];
    
    [textStorage appendAttributedString:as];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayBeepPacket:(BeepPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = [NSString stringWithFormat:@"[=Beep!=] %@ has sent you a beep\n", p.nick];

    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSLinkAttributeName value:p.nick range:NSMakeRange(10, [p.nick length])];
    
    [textStorage appendAttributedString:as];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
    
    NSBeep();
}

- (void)displayExitPacket:(ExitPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = @"[=Disconnected=]\n";
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayPingPacket:(PingPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = @"[=Ping!=]\n";
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayProtocolPacket:(ProtocolPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"Connected to the %@ server (%@)\n",
                   p.serverName, p.serverDescription];
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayStatusPacket:(StatusPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"[=%@=] %@\n", p.header, p.text];
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayErrorPacket:(ErrorPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"[=Error=] %@\n", p.errorText];
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (void)displayCommandOutputPacket:(CommandOutputPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = nil;
    
    if ([p.outputType compare:@"gh"] == NSOrderedSame)
    {
        s = @"Group     ## S  Moderator    \n";
        [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    }
    else if ([p.outputType compare:@"wh"] == NSOrderedSame)
    {
        s = @"   Nickname      Idle      Sign-on  Account\n";
        [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    }
    else if ([p.outputType compare:@"wl"] == NSOrderedSame)
    {
        NSMutableString *ms = [NSMutableString stringWithCapacity:80];
        [ms appendFormat:@"%c", [p isModerator] ? '*' : ' '];
        
        NSString *nickname = [p nickname];
        [ms appendFormat:@"%@", nickname];
        NSUInteger pad = 12 - [nickname length];
        if (pad > 0)
        {
            [ms appendString:[@"" stringByPaddingToLength:pad
                                               withString:@" "
                                          startingAtIndex:0]];
        }

        [ms appendFormat:@" %@ ", [self formatElapsedTime:[p idleTime]]];
        [ms appendFormat:@"%@ ", [self formatEventTime:[p signOnTime]]];
        [ms appendFormat:@"%@@%@\n", p.username, p.hostname];
        s = ms;
        NSLog(@"wl=%@", s);
        
        NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
        [as addAttribute:NSLinkAttributeName value:[p nickname] range:NSMakeRange(1, [[p nickname] length])];
        [textStorage appendAttributedString:as];
    }
    else
    {
        s = [NSString stringWithFormat:@"%@\n", p.output];
        [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
    }
    
    [textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
}

- (NSString *)formatElapsedTime:(NSTimeInterval)elapsedTime
{
    return [DateTimeUtils formatElapsedTime:elapsedTime];
}

- (NSString *)formatEventTime:(NSDate *)time
{
    return [DateTimeUtils formatEventTime:time];
}

- (void)clientNotify:(NSNotification *)notification
{
    if ([[notification name] compare:@"ICBClient:loginOK"] == NSOrderedSame)
    {
        //        [MBProgressHUD hideHUDForView:self.view animated:YES];
        //        [self performSegueWithIdentifier:@"connectSegue" sender:self];
        NSLog(@"login ok!!");
    }
}

@end
