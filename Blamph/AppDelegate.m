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

@synthesize progressIndicator;
@synthesize inputTextView;
@synthesize outputTextView;
@synthesize connectMenuItem;
@synthesize disconnectMenuItem;
@synthesize menuItemCopy;
@synthesize menuItemPaste;
@synthesize menuItemToggleStatusBar;
@synthesize statusBarView;
@synthesize connectionStatusLabel;
@synthesize connectionTimeLabel;
@synthesize idleTimeLabel;
@synthesize timer;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    backgroundColor = [NSColor whiteColor];
    openTextColor = [NSColor blackColor];
    openNickColor = [NSColor blueColor];
    personalTextColor = [NSColor darkGrayColor];
    personalNickColor = [NSColor lightGrayColor];
    commandTextColor = [NSColor blackColor];
    errorTextColor = [NSColor redColor];
    statusHeaderColor = [NSColor orangeColor];
    statusTextColor = [NSColor blackColor];
    
    servers = [NSMutableArray arrayWithObjects:

               [[ServerDefinition alloc] initWithName:@"localhost"
                                          andHostname:@"localhost"
                                              andPort:7326],

               [[ServerDefinition alloc] initWithName:@"default"
                                          andHostname:@"default.icb.net"
                                              andPort:7326],

               nil];

    [self.outputTextView setBackgroundColor:backgroundColor];
    [self.outputTextView setTextColor:commandTextColor];
    
    [self.window makeFirstResponder:self.inputTextView];
    
    connectionState = DISCONNECTED;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    BOOL valid = YES;
    if (menuItem == self.connectMenuItem)
    {
        valid = (connectionState == DISCONNECTED);
    }
    else if (menuItem == self.disconnectMenuItem)
    {
        valid = (connectionState == CONNECTED || connectionState == CONNECTING);
    }
    return valid;
}

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    if (aTextView != self.inputTextView)
        return NO;
    
    if (aSelector == @selector(insertNewline:))
    {
        NSString *text = [[aTextView textStorage] string];
        [self submitTextInput:text];
        [aTextView selectAll:nil];
        [aTextView delete:nil];
        return YES;
    }
    return NO;
}

- (void)submitTextInput:(NSString *)cmd
{
    
    if (cmd == nil || [cmd length] == 0)
        return;
    
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
    
    lastMessageSentAt = [NSDate date];
}

- (void)displayText:(NSString *)text
     withForeground:(NSColor *)foreground
      andBackground:(NSColor *)background
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:text];
    [as addAttribute:NSBackgroundColorAttributeName
               value:background
               range:NSMakeRange(0, [text length])];
    [as addAttribute:NSForegroundColorAttributeName
               value:foreground
               range:NSMakeRange(0, [text length])];
    
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?s)((?:\\w+://|\\bwww\\.[^.])\\S+)"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    
    NSArray *matches = [regex matchesInString:text
                                      options:0
                                        range:NSMakeRange(0, [text length])];
    
    for (NSTextCheckingResult *match in matches)
    {
        NSRange urlRange = [match rangeAtIndex:1];
        NSString *urlText = [text substringWithRange:urlRange];
        DLog(@"urlText='%@'", urlText);
        
        [as addAttribute:NSLinkAttributeName
                   value:[NSURL URLWithString:urlText]
                   range:urlRange];
    }
    
    [textStorage appendAttributedString:as];
}


- (BOOL)textView:(NSTextView *)aTextView
   clickedOnLink:(id)link
         atIndex:(NSUInteger)charIndex
{
    if (aTextView != self.outputTextView)
        return NO;

    BOOL handled = NO;
    if ([link isKindOfClass:[NSURL class]])
    {
        [[NSWorkspace sharedWorkspace] openURL:link];
        handled = YES;
    }
    else if ([link isKindOfClass:[NSString class]])
    {
        NSError *error = NULL;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\S*)\\s*(\\S*)(.*)"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        NSString *nickname = link;
        
        NSTextStorage *storage = [self.inputTextView textStorage];
        [storage beginEditing];
        
        NSString *inputText = [storage string];
        NSString *newText;
        
        if ([inputText length] > 0 && [inputText characterAtIndex:0] == '/')
        {
            NSArray *matches = [regex matchesInString:inputText
                                              options:0
                                                range:NSMakeRange(1, [inputText length] - 1)];
            if ([matches count] > 0)
            {
                NSTextCheckingResult *match = [matches objectAtIndex:0];
                NSRange commandRange = [match rangeAtIndex:1];
                NSRange argsRange = [match rangeAtIndex:2];
                NSString *command = [inputText substringWithRange:commandRange];
                NSString *args = [inputText substringWithRange:argsRange];
                newText = [NSString stringWithFormat:@"/%@ %@ %@", command, nickname, args];
            }
        }
        else
        {
            newText = [NSString stringWithFormat:@"/m %@ %@", nickname, inputText];
        }
        
        [self.inputTextView selectAll:nil];
        [self.inputTextView setString:newText];
        [storage endEditing];
        
        NSRange range = NSMakeRange(storage.length - 1, 1);
        [self.inputTextView scrollRangeToVisible:range];
        [self.window makeFirstResponder:self.inputTextView];
        
        handled = YES;
    }
    return handled;
}

- (void)changeConnectionState:(int)newState
{
    connectionState = newState;
    NSString *newLabel = nil;
    switch (connectionState)
    {
        case DISCONNECTED:
            newLabel = @"Disconnected";
            break;
        case CONNECTING:
            newLabel = @"Connecting";
            break;
        case CONNECTED:
            newLabel = @"Connected";
            break;
        case DISCONNECTING:
            newLabel = @"Disconnecting";
            break;
        default:
            newLabel = @"WTF?!";
            break;
    }
    [connectionStatusLabel setStringValue:newLabel];
}

- (IBAction)connect:(id)sender
{
    if (connectionState != DISCONNECTED)
    {
        // TODO: error, bitch!
        NSBeep();
    }
    else
    {
        [self changeConnectionState:CONNECTING];
        
        [progressIndicator setHidden:NO];
        [progressIndicator startAnimation:self];
        
        NSString *nickname = @"chadwick2";
        NSUInteger server = 0;
        
        ServerDefinition *serverDefinition = (ServerDefinition *)[servers objectAtIndex:server];
        if (serverDefinition != nil)
        {
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
}

- (IBAction)disconnect:(id)sender
{
    NSLog(@"disconnect action");
    if (connectionState != CONNECTED)
    {
        // TODO: error, bitch!
        NSBeep();
    }
    else
    {
        [self changeConnectionState:DISCONNECTING];
        [client disconnect];
    }
}

- (IBAction)copy:(id)sender
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    (void)[pasteboard clearContents];
    NSArray *selectedRanges = [self.outputTextView selectedRanges];
    NSMutableArray *selectedText = [NSMutableArray arrayWithCapacity:[selectedRanges count]];
    for (NSValue *rangeValue in selectedRanges)
    {
        NSRange r = [rangeValue rangeValue];
        [selectedText addObject:[[self.outputTextView textStorage] attributedSubstringFromRange:r]];
    }
    
    (void)[pasteboard writeObjects:selectedText];
}

- (IBAction)paste:(id)sender
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *classes = [[NSArray alloc] initWithObjects:[NSString class], nil];
    NSDictionary *options = [NSDictionary dictionary];
    NSArray *copiedItems = [pasteboard readObjectsForClasses:classes
                                                     options:options];
    if (copiedItems != nil)
    {
        [self.inputTextView pasteAsPlainText:copiedItems];
        [self.window makeFirstResponder:self.inputTextView];
    }
}

- (IBAction)toggleStatusBar:(id)sender
{
    
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
    else if ([packet isKindOfClass:[LoginPacket class]])
    {
        [[self.outputTextView.textStorage mutableString] appendString:@"\n"];
    }

    // TODO: don't scroll down if scrolled-back
    NSRange range = NSMakeRange(self.outputTextView.textStorage.length - 1, 1);
    [self.outputTextView scrollRangeToVisible:range];
    [self.outputTextView.textStorage setFont:[NSFont fontWithName:@"Monaco" size:12.0f]];
    
//    NSTextCheckingTypes oldTypes = self.outputTextView.enabledTextCheckingTypes;
//    [self.outputTextView setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
//    [self.outputTextView checkTextInDocument:nil];
//    [self.outputTextView setEnabledTextCheckingTypes:oldTypes];
}

- (void)displayMessageTimestamp
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, now);

    CFLocaleRef currentLocale = CFLocaleCopyCurrent();
    
    CFDateFormatterRef dateFormatter = CFDateFormatterCreate
    (NULL, currentLocale, kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
    
    CFStringRef formattedString = CFDateFormatterCreateStringWithDate(NULL, dateFormatter, date);
    
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = [NSString stringWithFormat:@"%@ ", formattedString];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:s];
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSForegroundColorAttributeName
               value:openTextColor
               range:NSMakeRange(0, [as length])];
    
    [textStorage appendAttributedString:as];
    
}

- (void)displayOpenPacket:(OpenPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"<%@>", p.nick];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSLinkAttributeName value:p.nick
               range:NSMakeRange(1, [p.nick length])];
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, [p.nick length] + 2)];
    [as addAttribute:NSForegroundColorAttributeName
               value:openNickColor
               range:NSMakeRange(0, [p.nick length] + 2)];

    [textStorage appendAttributedString:as];
    
    [self displayText:[NSString stringWithFormat:@" %@\n", p.text]
       withForeground:openTextColor
        andBackground:backgroundColor];
}

- (void)displayPersonalPacket:(PersonalPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"<*%@*>", p.nick];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSLinkAttributeName
               value:p.nick
               range:NSMakeRange(2, [p.nick length])];
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, [p.nick length] + 4)];
    [as addAttribute:NSForegroundColorAttributeName
               value:personalNickColor
               range:NSMakeRange(0, [p.nick length] + 4)];
    
    [textStorage appendAttributedString:as];
    [self displayText:[NSString stringWithFormat:@" %@\n", p.text]
       withForeground:personalTextColor
        andBackground:backgroundColor];
}

- (void)displayBeepPacket:(BeepPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = [NSString stringWithFormat:@"[=Beep!=] %@ has sent you a beep\n", p.nick];
    const NSUInteger headerLength = 10; // [=Beep=]<space> == 10
    const NSUInteger textLength = [s length];
    const NSUInteger nickLength = [p.nick length];

    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, textLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:statusHeaderColor
               range:NSMakeRange(0, headerLength)];
    [as addAttribute:NSLinkAttributeName
               value:p.nick
               range:NSMakeRange(headerLength, nickLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:statusTextColor
               range:NSMakeRange(headerLength + nickLength, textLength - nickLength - headerLength)];
    
    [textStorage appendAttributedString:as];
    
    NSBeep();
}

- (void)displayExitPacket:(ExitPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:@"[=Disconnected=]\n"];

    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSForegroundColorAttributeName
               value:statusHeaderColor
               range:NSMakeRange(0, [as length])];
    
    [textStorage appendAttributedString:as];
}

- (void)displayPingPacket:(PingPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:@"[=Ping!=]\n"];
    
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSForegroundColorAttributeName
               value:statusHeaderColor
               range:NSMakeRange(0, [as length])];
    
    [textStorage appendAttributedString:as];
}

- (void)displayProtocolPacket:(ProtocolPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = [NSString stringWithFormat:@"Connected to the %@ server (%@)\n",
                   p.serverName, p.serverDescription];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];

    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSForegroundColorAttributeName
               value:commandTextColor
               range:NSMakeRange(0, [as length])];
    
    [textStorage appendAttributedString:as];
}

- (void)displayStatusPacket:(StatusPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = [NSString stringWithFormat:@"[=%@=] %@\n", p.header, p.text];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    NSUInteger textLength = [as length];
    NSUInteger headerLength = 4 + [p.header length];
    
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, textLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:statusHeaderColor
               range:NSMakeRange(0, headerLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:statusTextColor
               range:NSMakeRange(headerLength + 1, textLength - headerLength - 1)];
    

    [textStorage appendAttributedString:as];
}

- (void)displayErrorPacket:(ErrorPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = [NSString stringWithFormat:@"[=Error=] %@\n", p.errorText];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    NSUInteger textLength = [as length];
    NSUInteger headerLength = 9; // [=Error=]
    
    [as addAttribute:NSBackgroundColorAttributeName
               value:backgroundColor
               range:NSMakeRange(0, textLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:errorTextColor
               range:NSMakeRange(0, headerLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:errorTextColor
               range:NSMakeRange(headerLength + 1, textLength - headerLength - 1)];
    
    [textStorage appendAttributedString:as];
}

- (void)displayCommandOutputPacket:(CommandOutputPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;

    NSString *s = nil;
    NSMutableAttributedString *as = nil;
    
    if ([p.outputType compare:@"gh"] == NSOrderedSame)
    {
        as = [[NSMutableAttributedString alloc] initWithString:@"Group     ## S  Moderator    \n"];
        [as addAttribute:NSBackgroundColorAttributeName
                   value:backgroundColor
                   range:NSMakeRange(0, [as length])];
        [as addAttribute:NSForegroundColorAttributeName
                   value:commandTextColor
                   range:NSMakeRange(0, [as length])];
        [textStorage appendAttributedString:as];
    }
    else if ([p.outputType compare:@"wh"] == NSOrderedSame)
    {
        as = [[NSMutableAttributedString alloc] initWithString:@"   Nickname      Idle      Sign-on  Account\n"];
        [as addAttribute:NSBackgroundColorAttributeName
                   value:backgroundColor
                   range:NSMakeRange(0, [as length])];
        [as addAttribute:NSForegroundColorAttributeName
                   value:commandTextColor
                   range:NSMakeRange(0, [as length])];
        [textStorage appendAttributedString:as];
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

        NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
        [as addAttribute:NSBackgroundColorAttributeName
                   value:backgroundColor
                   range:NSMakeRange(0, [as length])];
        [as addAttribute:NSForegroundColorAttributeName
                   value:commandTextColor
                   range:NSMakeRange(0, [as length])];
        [as addAttribute:NSForegroundColorAttributeName
                   value:openNickColor
                   range:NSMakeRange(1, [[p nickname] length])];
        [as addAttribute:NSLinkAttributeName
                   value:[p nickname]
                   range:NSMakeRange(1, [[p nickname] length])];
        [textStorage appendAttributedString:as];
    }
    else
    {
        [self displayText:[NSString stringWithFormat:@"%@\n", p.output]
           withForeground:commandTextColor
            andBackground:backgroundColor];
    }
}

- (NSString *)formatElapsedTime:(NSTimeInterval)elapsedTime
{
    return [DateTimeUtils formatElapsedTime:elapsedTime];
}

- (NSString *)formatEventTime:(NSDate *)time
{
    return [DateTimeUtils formatEventTime:time];
}

- (void)fireTimer:(id)arg
{
    DLog(@"timer fired");
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    NSTimeInterval start = [connectedTime timeIntervalSince1970];
    NSTimeInterval elapsedTime = now - start;
    NSString *elapsedText = [DateTimeUtils formatSimpleTime:elapsedTime];
    [connectionTimeLabel setStringValue:[NSString stringWithFormat:@"Connected: %@", elapsedText]];
    
    start = [lastMessageSentAt timeIntervalSince1970];
    NSTimeInterval idleTime = now - start;
    NSString *idleText = [DateTimeUtils formatSimpleTime:idleTime];
    [idleTimeLabel setStringValue:[NSString stringWithFormat:@"Idle: %@", idleText]];
}

- (void)clientNotify:(NSNotification *)notification
{
    if ([[notification name] compare:@"ICBClient:connected"] == NSOrderedSame)
    {
        [progressIndicator stopAnimation:self];
        [progressIndicator setHidden:YES];
        [self changeConnectionState:CONNECTED];
        [self.idleTimeLabel setHidden:NO];
        [self.connectionTimeLabel setHidden:NO];

        connectedTime = [NSDate date];
        lastMessageSentAt = [NSDate date];
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(fireTimer:)
                                                    userInfo:nil
                                                     repeats:YES];
    }
    else if ([[notification name] compare:@"ICBClient:disconnected"] == NSOrderedSame)
    {
        [self changeConnectionState:DISCONNECTED];
        [self.timer invalidate];
        self.timer = nil;
        [self.idleTimeLabel setHidden:YES];
        [self.connectionTimeLabel setHidden:YES];
    }
    else if ([[notification name] compare:@"ICBClient:loginOK"] == NSOrderedSame)
    {
        //        [MBProgressHUD hideHUDForView:self.view animated:YES];
        //        [self performSegueWithIdentifier:@"connectSegue" [er:self];
    }
}

@end
