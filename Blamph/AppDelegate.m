//
//  AppDelegate.m
//  Blamph
//
//  Created by Chad Gibbons on 10/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "AppDelegate.h"
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
        
        if ([cmd characterAtIndex:0] != '/')
        {
            [self sendOpenMessage:cmd];
        }
        else if ([cmd characterAtIndex:1] == '/')
        {
            [self sendOpenMessage:[cmd substringFromIndex:1]];
        }
        else
        {
            [self sendPersonalMessage:@"server" withMsg:[cmd substringFromIndex:1]];
        }
    }
    
    return YES;
}

- (NSString *)removeControlCharacters:(NSString *)s
{
    const NSUInteger n = [s length];
    NSMutableString *t = [NSMutableString stringWithCapacity:n];
    char c;
    for (NSUInteger i = 0; i < n; i++)
    {
        c = [s characterAtIndex:i];
        if (isspace(c))
            [t appendFormat:@"%c", c];
        else if (!iscntrl(c))
            [t appendFormat:@"%c", c];
    }
    return t;
}

- (void)sendOpenMessage:(NSString *)msg
{
    NSString *current;
    NSString *remaining = [self removeControlCharacters:msg];
    do {
        if ([remaining length] > MAX_OPEN_MESSAGE_SIZE)
        {
            current = [remaining substringToIndex:MAX_OPEN_MESSAGE_SIZE];
            NSRange range = [current rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                     options:NSBackwardsSearch];
            if (range.location != NSNotFound)
            {
                current = [current substringWithRange:NSMakeRange(0, range.location + 1)];
            }
            remaining = [remaining substringFromIndex:[current length]];
        }
        else
        {
            current = remaining;
            remaining = @"";
        }
        
        OpenPacket *p = [[OpenPacket alloc] initWithText:current];
        [client sendPacket:p];
    } while ([remaining length] > 0);
}

- (void)sendPersonalMessage:(NSString *)nick withMsg:(NSString *)msg
{
    NSString *current;
    NSString *remaining = [self removeControlCharacters:msg];
    do {
        if ([remaining length] > MAX_PERSONAL_MESSAGE_SIZE)
        {
            current = [remaining substringToIndex:MAX_PERSONAL_MESSAGE_SIZE];
            NSRange range = [current rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                     options:NSBackwardsSearch];
            if (range.location != NSNotFound)
            {
                current = [current substringWithRange:NSMakeRange(0, range.location + 1)];
            }
            remaining = [remaining substringFromIndex:[current length]];
        }
        else
        {
            current = remaining;
            remaining = @"";
        }
        
        NSString *s = [NSString stringWithFormat:@"%@ %@", nick, current];
        CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"m" optionalArgs:s];
        [client sendPacket:p];
    } while ([remaining length] > 0);
    
    // TODO: add outgoing username to history
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

- (IBAction)makeKeyAndOrderFront:(id)sender
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
    [as addAttribute:NSLinkAttributeName value:p.nick range:NSMakeRange(11, [p.nick length])];
    
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
    
    if ([p.outputType compare:@"wh"] == NSOrderedSame)
    {
        s = @"\t\tNickname\tIdle\tSign-on\tAccount\n";
    }
    else if ([p.outputType compare:@"wl"] == NSOrderedSame)
    {
        NSMutableString *ms = [NSMutableString stringWithCapacity:80];
        [ms appendFormat:@"\t%c\t", [p isModerator] ? '*' : ' '];
        [ms appendFormat:@"%@\t", [p nickname]];
        [ms appendFormat:@"%@\t", [self formatElapsedTime:[p idleTime]]];
        [ms appendFormat:@"%@\t", [self formatEventTime:[p signOnTime]]];
        [ms appendFormat:@"%@@%@\n", p.username, p.hostname];
        s = ms;
        NSLog(@"wl=%@", s);
    }
    else
    {
        s = [NSString stringWithFormat:@"%@\n", p.output];
    }
    [textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:s]];
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
