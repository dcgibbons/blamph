//
//  UIController.m
//  Blamph
//
//  Created by Chad Gibbons on 11/15/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "UIController.h"
#import "ClientCommand.h"
#import "DateTimeUtils.h"
#import "BeepPacket.h"
#import "CommandPacket.h"
#import "CommandOutputPacket.h"
#import "ErrorPacket.h"
#import "ExitPacket.h"
#import "LoginPacket.h"
#import "PersonalPacket.h"
#import "PingPacket.h"
#import "PongPacket.h"
#import "ProtocolPacket.h"
#import "OpenPacket.h"
#import "StatusPacket.h"
#import "URLHelper.h"

@interface UIController()
{
@private
    NSColor *_backgroundColor;
    NSColor *_openTextColor;
    NSColor *_openNickColor;
    NSColor *_personalTextColor;
    NSColor *_personalNickColor;
    NSColor *_commandTextColor;
    NSColor *_errorTextColor;
    NSColor *_statusHeaderColor;
    NSColor *_statusTextColor;
    NSColor *_timestampColor;
    NSColor *_inputColor;
    
    NSFont *_outputFont;
    NSFont *_timestampFont;
    
    NSDate *_connectedTime;
    NSDate *_lastMessageSentAt;
    
    NSDictionary *_packetHandlers;
    
    NSUInteger _inputHistoryIndex;
    NSMutableArray *_inputHistory;
    NSString *_savedInputBuffer;
}
@end

@implementation UIController

@synthesize progressIndicator=_progressIndicator;
@synthesize inputTextView=_inputTextView;
@synthesize outputTextView=_outputTextView;
@synthesize connectMenuItem=_connectMenuItem;
@synthesize disconnectMenuItem=_disconnectMenuItem;
@synthesize menuItemCopy=_menuItemCopy;
@synthesize menuItemPaste=_menuItemPaste;
@synthesize menuItemToggleStatusBar=_menuItemToggleStatusBar;
@synthesize menuItemUseTransparency=_menuItemUseTransparency;
@synthesize menuItemIncreaseFontSize=_menuItemIncreaseFontSize;
@synthesize menuItemDefaultFontSize=_menuItemDefaultFontSize;
@synthesize menuItemDecreaseFontSize=_menuItemDecreaseFontSize;
@synthesize splitView=_splitView;
@synthesize bottomConstraint=_bottomConstraint;
@synthesize statusBarView=_statusBarView;
@synthesize connectionStatusLabel=_connectionStatusLabel;
@synthesize connectionTimeLabel=_connectionTimeLabel;
@synthesize idleTimeLabel=_idleTimeLabel;
@synthesize timer=_timer;
@synthesize inputScrollView=_inputScrollView;
@synthesize outputScrollView=_outputScrollView;
@synthesize heightConstraint=_heightConstraint;

#define kOutputScrollbackSize       1000
#define kColorSchemeDefault         1001
#define kColorSchemeOldSchool       1002

#define kFontName                   @"Menlo"
#define kTextStyle                  @"textStyle"
#define kTextStyleTimestamp         @"textStyleTimestamp"
#define kTextStyleOpenNick          @"textStyleOpenNick"
#define kTextStyleOpenText          @"textStyleOpenText"
#define kTextStylePersonalNick      @"textStylePersonalNick"
#define kTextStylePersonalText      @"textStylePersonalText"
#define kTextStyleStatusHeader      @"textStyleStatusHeader"
#define kTextStyleStatusText        @"textStyleStatusText"
#define kTextStyleCommandText       @"textStyleCommandText"
#define kTextStyleErrorHeader       @"textStyleErrorHeader"
#define kTextStyleErrorText         @"textStyleErrorText"

#define kColorScheme                @"colorScheme"
#define kUseTransparency            @"useTransparency"
#define kOpacityLevel               @"opacityLevel"
#define kOutputFontPointSize        @"outputFontPointSize"
#define kTimestampFontPointSize     @"timestampFontPointSize"

#define kCommandPrefix              '/'

#define kDefaultOutputFontSize      12.0
#define kDefaultTimestampFontSize   10.0

#define kMaxInputHistorySize        100

+ (void)initialize
{
    // load the default values for the user defaults
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithInt:kColorSchemeDefault], kColorScheme,
                       [NSNumber numberWithBool:YES], kUseTransparency,
                       [NSNumber numberWithFloat:0.75], kOpacityLevel,
                       [NSNumber numberWithDouble:kDefaultOutputFontSize], kOutputFontPointSize,
                       [NSNumber numberWithDouble:kDefaultTimestampFontSize], kTimestampFontPointSize,
                       nil];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults registerDefaults:d];

    [userDefaults setBool:YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];
}

- (id)init
{
    if (self = [super init])
    {
        [self setupPacketHandlers];
        
        _inputHistory = [NSMutableArray arrayWithCapacity:100];
        _inputHistoryIndex = 0;
        _savedInputBuffer = nil;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientNotify:)
                                                     name:nil
                                                   object:self.client];
        
        // Observer particular user defaults so we can update the UI anytime
        // they change.
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        [userDefaults addObserver:self
                       forKeyPath:kUseTransparency
                          options:NSKeyValueObservingOptionNew
                          context:NULL];

        [userDefaults addObserver:self
                       forKeyPath:kOpacityLevel
                          options:NSKeyValueObservingOptionNew
                          context:NULL];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    _outputFont = [NSFont fontWithName:kFontName
                                 size:[userDefaults doubleForKey:kOutputFontPointSize]];
    _timestampFont = [NSFont fontWithName:kFontName
                                    size:[userDefaults doubleForKey:kTimestampFontPointSize]];
    
    NSInteger colorScheme = [[userDefaults valueForKey:kColorScheme] intValue];
    switch (colorScheme)
    {
        case kColorSchemeDefault:
            [self selectDefaultColors];
            break;
        case kColorSchemeOldSchool:
            [self selectOldSchoolColors];
            break;
    }

    [self.inputTextView setFont:_outputFont];
    [self.outputTextView setFont:_outputFont];
    [self.outputTextView setBackgroundColor:_backgroundColor];
    [self.outputTextView setTextColor:_commandTextColor];

    [self didUpdateFonts];

    [self.window makeFirstResponder:self.inputTextView];

    [self setTransparency:[userDefaults boolForKey:kUseTransparency]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    BOOL valid = YES;

    if (menuItem == self.connectMenuItem)
    {
        valid = ![self.client isConnected];
    }
    else if (menuItem == self.disconnectMenuItem)
    {
        valid = [self.client isConnected];
    }
    else if (menuItem == self.menuItemDefaultColorScheme)
    {
        NSInteger colorScheme = [userDefaults integerForKey:kColorScheme];
        [menuItem setState:(colorScheme == kColorSchemeDefault) ? NSOnState : NSOffState];
    }
    else if (menuItem == self.menuItemOldSchoolColorScheme)
    {
        NSInteger colorScheme = [userDefaults integerForKey:kColorScheme];
        [menuItem setState:(colorScheme == kColorSchemeOldSchool) ? NSOnState : NSOffState];
    }

    return valid;
}

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    BOOL handled = NO;

    if (aTextView == self.inputTextView)
    {
        if (aSelector == @selector(insertNewline:))
        {
            NSString *text = [[aTextView textStorage] string];
            [self submitTextInput:text];
            [aTextView selectAll:nil];
            [aTextView delete:nil];
            handled = YES;
        }
        else if (aSelector == @selector(insertTab:))
        {
            NSString *nickname = [self.client.nicknameHistory next];
            if (nickname != nil)
            {
                [self setNickname:nickname];
            }
            else
            {
                NSBeep();
            }
            handled = YES;
        }
        else if (aSelector == @selector(moveUp:))
        {
            if (_inputHistoryIndex == 0)
            {
                NSBeep();
            }
            else
            {
                // If we're at the end of the history and scrolling back, then we need to
                // make sure we save any currently entered text so the user may return to
                // it later. This is cached outside of the inputHistory list so that it
                // won't be saved in case the user selects an older history item to use as
                // input.
                if (_inputHistoryIndex == [_inputHistory count])
                {
                    _savedInputBuffer = [NSString stringWithString:[self.inputTextView string]];
                }
                
                _inputHistoryIndex--;
                NSString *inputBuffer = [_inputHistory objectAtIndex:_inputHistoryIndex];
                [self.inputTextView setString:inputBuffer];
            }

            handled = YES;
        }
        else if (aSelector == @selector(moveDown:))
        {
            NSUInteger count = [_inputHistory count];
            if (_inputHistoryIndex < count - 1)
            {
                _inputHistoryIndex++;
                NSString *inputBuffer = [_inputHistory objectAtIndex:_inputHistoryIndex];
                [self.inputTextView setString:inputBuffer];
            }
            else if (_inputHistoryIndex == count - 1)
            {
                _inputHistoryIndex = count;
                if (_savedInputBuffer)
                {
                    [self.inputTextView setString:_savedInputBuffer];
                    _savedInputBuffer = nil;
                }
            }
            else
            {
                NSBeep();
            }
        }
    }

    return handled;
}

- (void)addToInputHistory:(NSString *)input
{
    NSUInteger n = [_inputHistory count];
    if (n == kMaxInputHistorySize)
    {
        [_inputHistory removeObjectAtIndex:0];
    }
    
    // Add a copy of the input buffer to the input history array - keep a copy
    // in case that string is a mutable string that can change elsewhere
    [_inputHistory addObject:[NSString stringWithString:input]];
    _inputHistoryIndex = [_inputHistory count];
}

- (void)submitTextInput:(NSString *)cmd
{
    if (cmd == nil || [cmd length] == 0)
        return;
    
    [self addToInputHistory:cmd];
    
    // if the input isn't prefixed with the command character just send
    // the text as an open message
    if ([cmd characterAtIndex:0] != kCommandPrefix)
    {
        [self.client sendOpenMessage:cmd];
    }
    
    // check if they escaped the / with another and send it as an open
    // message
    else if ([cmd characterAtIndex:1] == kCommandPrefix)
    {
        [self.client sendOpenMessage:[cmd substringFromIndex:1]];
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
            [self.client sendPersonalMessage:@"server"
                                withMsg:cmd];
        }
        else
        {
            [command processCommandWithClient:self.client];
        }
    }
    
    _lastMessageSentAt = [NSDate date];
}

- (void)setNickname:(NSString *)nickname
{
    // Parse the current input text to look to see if there is matching pattern
    // for a command that includes a user's nickname, such as /m foo bar.
    // If a matching pattern is found, replace the nickname in the current text
    // with the one specified, otherwise change the input string to be
    // /m <newnick> <text>.
    
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\S*)\\s*(\\S*)(.*)"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    NSTextStorage *storage = [self.inputTextView textStorage];
    [storage beginEditing];
    
    NSString *inputText = [storage string];
    NSString *newText;
    
    if ([inputText length] > 0 && [inputText characterAtIndex:0] == kCommandPrefix)
    {
        NSArray *matches = [regex matchesInString:inputText
                                          options:0
                                            range:NSMakeRange(1, [inputText length] - 1)];
        if ([matches count] > 0)
        {
            NSTextCheckingResult *match = [matches objectAtIndex:0];
            NSRange commandRange = [match rangeAtIndex:1];
            NSRange argsRange = [match rangeAtIndex:3];
            NSString *command = [inputText substringWithRange:commandRange];
            NSString *args = [[inputText substringWithRange:argsRange]
                              stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
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
}

- (BOOL)textView:(NSTextView *)aTextView
   clickedOnLink:(id)link
         atIndex:(NSUInteger)charIndex
{
    BOOL handled = NO;
    if (aTextView == self.outputTextView)
    {
        if ([link isKindOfClass:[NSURL class]])
        {
            [[NSWorkspace sharedWorkspace] openURL:link];
            handled = YES;
        }
        else if ([link isKindOfClass:[NSString class]])
        {
            NSString *nickname = link;
            [self setNickname:nickname];
            handled = YES;
        }
    }
    return handled;
}

- (IBAction)selectAll:(id)sender
{
    [self.inputTextView selectAll:sender];
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
    [self.inputTextView pasteAsPlainText:self];
    [self.window makeFirstResponder:self.inputTextView];
}

- (IBAction)pasteSpecial:(id)sender
{
    // a special paste will look for URLs in the pasteboard text and then
    // send them to a URL shortener processor before they are pasted to the
    // input buffer
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *classes = [[NSArray alloc] initWithObjects:[NSString class], nil];
    NSDictionary *options = [NSDictionary dictionary];
    NSArray *copiedItems = [pasteboard readObjectsForClasses:classes
                                                     options:options];
    for (NSString *text in copiedItems)
    {
        NSError *error = NULL;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:kURLPattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        
        NSArray *matches = [regex matchesInString:text
                                          options:0
                                            range:NSMakeRange(0, [text length])];
        
        for (NSTextCheckingResult *match in matches)
        {
            NSRange urlRange = [match rangeAtIndex:1];
            NSString *urlText = [text substringWithRange:urlRange];
            [URLHelper shortenURL:[NSURL URLWithString:urlText]
                       toSelector:@selector(pasteURL:)
                         onObject:self];
        }
        
        // TODO: this special paste doesn't deal with the text in the pasteboard
        // that aren't URL's! whoops
    }
}

- (void)pasteURL:(NSString *)urlText
{
    [self.inputTextView insertText:urlText];
}

- (IBAction)toggleStatusBar:(id)sender
{
    BOOL isHidden = [self.statusBarView isHidden];
    [self.statusBarView setHidden:!isHidden];
    
    NSDictionary *views = nil;
    NSArray *constraints = nil;
    if (isHidden)
    {
        views = [NSDictionary dictionaryWithObjectsAndKeys:
                 self.splitView, @"splitview",
                 self.statusBarView, @"bottomview",
                 nil];
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[splitview]-(0)-[bottomview]"
                                                              options:0
                                                              metrics:nil
                                                                views:views];
    }
    else
    {
        // the status bar was previously visible, so change our bottom
        // constraint to be relative to the superview, not the status bar
        views = [NSDictionary dictionaryWithObjectsAndKeys:self.splitView, @"splitview",
                 nil];
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[splitview]-(0)-|"
                                                              options:0
                                                              metrics:nil
                                                                views:views];
    }
    
    [self.splitView.superview removeConstraints:[NSArray arrayWithObject:self.bottomConstraint]];
    self.bottomConstraint = constraints[0];
    [self.splitView.superview addConstraints:constraints];
    [self.splitView.superview setNeedsUpdateConstraints:YES];
}

- (IBAction)selectColorScheme:(id)sender
{
    if (sender == self.menuItemDefaultColorScheme)
    {
        [self selectDefaultColors];
    }
    else if (sender == self.menuItemOldSchoolColorScheme)
    {
        [self selectOldSchoolColors];
    }
}

- (IBAction)changeFontSize:(id)sender
{
    if (sender == self.menuItemIncreaseFontSize)
    {
        CGFloat pointSize = _outputFont.pointSize;
        pointSize += 1.0;
        _outputFont = [NSFont fontWithName:kFontName size:pointSize];
        
        pointSize = _timestampFont.pointSize;
        pointSize += 1.0;
        _timestampFont = [NSFont fontWithName:kFontName size:pointSize];
    }
    else if (sender == self.menuItemDecreaseFontSize)
    {
        CGFloat pointSize = _outputFont.pointSize;
        pointSize -= 1.0;
        _outputFont = [NSFont fontWithName:kFontName size:pointSize];
        
        pointSize = _timestampFont.pointSize;
        pointSize -= 1.0;
        _timestampFont = [NSFont fontWithName:kFontName size:pointSize];
    }
    else
    {
        _outputFont = [NSFont fontWithName:kFontName
                                      size:kDefaultOutputFontSize];
        _timestampFont = [NSFont fontWithName:kFontName
                                         size:kDefaultTimestampFontSize];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:[NSNumber numberWithDouble:[_outputFont pointSize]]
                    forKey:kOutputFontPointSize];
    [userDefaults setValue:[NSNumber numberWithDouble:[_timestampFont pointSize]]
                    forKey:kTimestampFontPointSize];

    [self didUpdateFonts];
}

- (void)setTransparency:(BOOL)transparent
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (transparent)
    {
        [self.window setOpaque:NO];
        CGFloat alpha = [userDefaults floatForKey:kOpacityLevel];
        _backgroundColor = [_backgroundColor colorWithAlphaComponent:alpha];
        [self didUpdateColorScheme];
    }
    else
    {
        [self.window setOpaque:YES];
        _backgroundColor = [_backgroundColor colorWithAlphaComponent:1.0];
        [self didUpdateColorScheme];
        //        [self.window setBackgroundColor:b];
    }
}

- (NSColor *)getForegroundColor:(NSString *)textStyle
{
    NSColor *foreground = nil;
    
    if ([textStyle compare:kTextStyleTimestamp] == NSOrderedSame)
    {
        foreground = _timestampColor;
    }
    else if ([textStyle compare:kTextStyleOpenNick] == NSOrderedSame)
    {
        foreground = _openNickColor;
    }
    else if ([textStyle compare:kTextStyleOpenText] == NSOrderedSame)
    {
        foreground = _openTextColor;
    }
    else if ([textStyle compare:kTextStylePersonalNick] == NSOrderedSame)
    {
        foreground = _openNickColor;
    }
    else if ([textStyle compare:kTextStylePersonalText] == NSOrderedSame)
    {
        foreground = _personalTextColor;
    }
    else if ([textStyle compare:kTextStyleStatusHeader] == NSOrderedSame)
    {
        foreground = _statusHeaderColor;
    }
    else if ([textStyle compare:kTextStyleStatusText] == NSOrderedSame)
    {
        foreground = _statusTextColor;
    }
    else if ([textStyle compare:kTextStyleCommandText] == NSOrderedSame)
    {
        foreground = _commandTextColor;
    }
    else if ([textStyle compare:kTextStyleErrorHeader] == NSOrderedSame)
    {
        foreground = _errorTextColor;
    }
    else if ([textStyle compare:kTextStyleErrorText] == NSOrderedSame)
    {
        foreground = _errorTextColor;
    }

    NSAssert(foreground != nil, @"unknown text style");
    return foreground;
}

- (void)didUpdateFonts
{
    [self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:self];
    
    NSTextStorage *textStorage = [self.outputTextView textStorage];
    [textStorage beginEditing];
    
    void (^searchBlock)(id, NSRange, BOOL *) = ^(id value, NSRange range, BOOL *stop)
    {
        *stop = NO;

        NSFont *font = _outputFont;
        if ([(NSString *)value compare:kTextStyleTimestamp] == NSOrderedSame)
        {
            font = _timestampFont;
        }
        
        [textStorage removeAttribute:NSFontAttributeName
                               range:range];
        [textStorage addAttribute:NSFontAttributeName
                            value:font
                            range:range];
    };

    [textStorage enumerateAttribute:kTextStyle
                            inRange:NSMakeRange(0, [textStorage length])
                            options:0
                         usingBlock:searchBlock];

    [self.inputTextView setFont:_outputFont];
    [self.outputTextView setFont:_outputFont];
    [textStorage endEditing];

    // Change the height constraint of the input scroll view to be 2x the height
    // of the font, which should give us two lines visually in the input
    // window.
    [self.inputScrollView removeConstraint:self.heightConstraint];
    CGRect boundingRect = [_outputFont boundingRectForFont];
    NSString *visualFormat = [NSString stringWithFormat:@"V:[inputScrollView(>=%lu)]",
                              (NSUInteger)boundingRect.size.height * 2];
    NSView *inputScrollView = self.inputScrollView;
    self.heightConstraint = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                                    options:0
                                                                    metrics:nil
                                                                      views:NSDictionaryOfVariableBindings(inputScrollView)][0];
    [self.inputScrollView addConstraint:self.heightConstraint];
    [self.inputScrollView.superview setNeedsUpdateConstraints:YES];
    
    [self.progressIndicator setHidden:YES];
    [self.progressIndicator stopAnimation:self];
}

- (void)didUpdateColorScheme
{
    [self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:self];
    
    NSTextStorage *textStorage = [self.outputTextView textStorage];
    [textStorage beginEditing];
    
    void (^searchBlock)(id, NSRange, BOOL *) = ^(id value, NSRange range, BOOL *stop)
    {
        *stop = NO;
        
        [textStorage addAttribute:NSBackgroundColorAttributeName
                            value:_backgroundColor
                            range:range];
        
        [textStorage addAttribute:NSForegroundColorAttributeName
                            value:[self getForegroundColor:value]
                            range:range];
    };
    
    [textStorage enumerateAttribute:kTextStyle
                            inRange:NSMakeRange(0, [textStorage length])
                            options:0
                         usingBlock:searchBlock];

    [textStorage endEditing];
    
    [self.inputTextView setBackgroundColor:_backgroundColor];
    [self.inputTextView setInsertionPointColor:_inputColor];
    [self.inputTextView setTextColor:_inputColor];
    [self.inputScrollView setBackgroundColor:_backgroundColor];
    
    [self.outputTextView setBackgroundColor:_backgroundColor];
    [self.outputScrollView setBackgroundColor:_backgroundColor];

    [self.progressIndicator setHidden:YES];
    [self.progressIndicator stopAnimation:self];
}

- (void)selectDefaultColors
{
    _backgroundColor = [NSColor whiteColor];
    _openTextColor = [NSColor blackColor];
    _openNickColor = [NSColor blueColor];
    _personalTextColor = [NSColor darkGrayColor];
    _personalNickColor = [NSColor lightGrayColor];
    _commandTextColor = [NSColor blackColor];
    _errorTextColor = [NSColor redColor];
    _statusHeaderColor = [NSColor orangeColor];
    _statusTextColor = [NSColor blackColor];
    _timestampColor = [NSColor lightGrayColor];
    _inputColor = [NSColor blackColor];

    [self.progressIndicator setControlTint:NSDefaultControlTint];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:kColorSchemeDefault forKey:kColorScheme];
    
    [self didUpdateColorScheme];
}

- (void)selectOldSchoolColors
{
    _backgroundColor = [NSColor blackColor];
    _openTextColor = [NSColor greenColor];
    _openNickColor = [NSColor blueColor];
    _personalTextColor = [NSColor colorWithSRGBRed:1.0 green:191.0/255.0 blue:0.0 alpha:1.0];
    _personalNickColor = [NSColor colorWithSRGBRed:1.0 green:126.0/255.0 blue:0.0 alpha:1.0];
    _commandTextColor = [NSColor colorWithSRGBRed:0xfa/255.0 green:0xe1/255.0 blue:0x34/255.0 alpha:1.0];
    _errorTextColor = [NSColor redColor];
    _statusHeaderColor = [NSColor orangeColor];
    _statusTextColor = [NSColor greenColor];
    _timestampColor = [NSColor lightGrayColor];
    _inputColor = [NSColor colorWithSRGBRed:0xfa/255.0 green:0xe1/255.0 blue:0x34/255.0 alpha:1.0];

    [self.progressIndicator setControlTint:NSBlueControlTint];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:kColorSchemeOldSchool forKey:kColorScheme];

    [self didUpdateColorScheme];
}

- (void)displayMessageTimestamp
{
    NSDate *now = [NSDate date];
    
    NSString *formattedString = [NSDateFormatter localizedStringFromDate:now
                                   dateStyle:NSDateFormatterNoStyle
                                   timeStyle:NSDateFormatterShortStyle];
    
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"%@ ", formattedString];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:s];
    
    NSRange range = NSMakeRange(0, [as length]);
    [as addAttribute:NSFontAttributeName
               value:_timestampFont
               range:range];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:range];
    [as addAttribute:NSForegroundColorAttributeName
               value:_timestampColor
               range:range];
    [as addAttribute:kTextStyle
               value:kTextStyleTimestamp
               range:range];
    
    [textStorage appendAttributedString:as];
}

- (void)displayText:(NSString *)text
      withTextStyle:(NSString *)textStyle
{
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:text];
    const NSRange textRange = NSMakeRange(0, [text length]);
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    
    NSColor *foreground = [self getForegroundColor:textStyle];
    NSColor *background = _backgroundColor;
    
    [as addAttribute:NSBackgroundColorAttributeName
               value:background
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:foreground
               range:textRange];
    [as addAttribute:kTextStyle
               value:textStyle
               range:textRange];
    
    [URLHelper findURLsInText:as];
    
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    [textStorage appendAttributedString:as];
}

- (void)displayOpenPacket:(OpenPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"<%@>", p.nick];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    
    const NSRange nickRange = NSMakeRange(0, [p.nick length] + 2);
    const NSRange nickOnlyRange = NSMakeRange(1, [p.nick length]);
    
    [as addAttribute:NSLinkAttributeName
               value:p.nick
               range:nickOnlyRange];
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:nickRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:nickRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_openNickColor
               range:nickRange];
    [as addAttribute:kTextStyle
               value:kTextStyleOpenNick
               range:nickRange];
    
    [textStorage appendAttributedString:as];
    
    [self displayText:[NSString stringWithFormat:@" %@\n", p.text]
        withTextStyle:kTextStyleOpenText];
}

- (void)displayPersonalPacket:(PersonalPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"<*%@*>", p.nick];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    
    const NSRange nickRange = NSMakeRange(0, [p.nick length] + 4);
    const NSRange nickOnlyRange = NSMakeRange(2, [p.nick length]);
    
    [as addAttribute:NSLinkAttributeName
               value:p.nick
               range:nickOnlyRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:nickRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_personalNickColor
               range:nickRange];
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:nickRange];
    [as addAttribute:kTextStyle
               value:kTextStylePersonalNick
               range:nickRange];

    [textStorage appendAttributedString:as];
    
    [self displayText:[NSString stringWithFormat:@" %@\n", p.text]
        withTextStyle:kTextStylePersonalText];
}

- (void)displayBeepPacket:(BeepPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"[=Beep!=] %@ has sent you a beep\n", p.nick];
    const NSUInteger headerLength = 10; // [=Beep=]<space> == 10
    const NSUInteger textLength = [s length];
    const NSUInteger nickLength = [p.nick length];
    
    const NSRange textRange = NSMakeRange(0, textLength);
    const NSRange headerRange = NSMakeRange(0, headerLength);
    const NSRange statusRange = NSMakeRange(headerLength + nickLength, textLength - nickLength - headerLength);
    const NSRange nickOnlyRange = NSMakeRange(headerLength, nickLength);
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    [as addAttribute:NSLinkAttributeName
               value:p.nick
               range:nickOnlyRange];
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_statusHeaderColor
               range:headerRange];
    [as addAttribute:kTextStyle
               value:kTextStyleStatusHeader
               range:headerRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_statusTextColor
               range:NSMakeRange(headerLength + nickLength, textLength - nickLength - headerLength)];
    [as addAttribute:kTextStyle
               value:kTextStyleStatusText
               range:statusRange];

    [textStorage appendAttributedString:as];
    
    NSBeep();
}

- (void)displayExitPacket:(ExitPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:@"[=Disconnected=]\n"];
    
    const NSRange textRange = NSMakeRange(0, [as length]);
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_statusHeaderColor
               range:textRange];
    [as addAttribute:kTextStyle
               value:kTextStyleStatusHeader
               range:textRange];
    
    [textStorage appendAttributedString:as];
}

- (void)displayPingPacket:(PingPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:@"[=Ping!=]\n"];
    
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSForegroundColorAttributeName
               value:_statusHeaderColor
               range:NSMakeRange(0, [as length])];
    [as addAttribute:kTextStyle
               value:kTextStyleStatusHeader
               range:NSMakeRange(0, [as length])];
    
    [textStorage appendAttributedString:as];
}

- (void)displayProtocolPacket:(ProtocolPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"Connected to the %@ server (%@)\n",
                   p.serverName, p.serverDescription];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    
    const NSRange textRange = NSMakeRange(0, [as length]);
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_commandTextColor
               range:textRange];
    [as addAttribute:kTextStyle
               value:kTextStyleCommandText
               range:textRange];
    
    [textStorage appendAttributedString:as];
}

- (void)displayStatusPacket:(StatusPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"[=%@=] %@\n", p.header, p.text];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    NSUInteger textLength = [as length];
    NSUInteger headerLength = 4 + [p.header length];
    
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:NSMakeRange(0, [as length])];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:NSMakeRange(0, textLength)];
    [as addAttribute:NSForegroundColorAttributeName
               value:_statusHeaderColor
               range:NSMakeRange(0, headerLength)];
    [as addAttribute:kTextStyle
               value:kTextStyleStatusHeader
               range:NSMakeRange(0, headerLength)];
    
    [as addAttribute:NSForegroundColorAttributeName
               value:_statusTextColor
               range:NSMakeRange(headerLength, textLength - headerLength)];
    [as addAttribute:kTextStyle
               value:kTextStyleStatusText
               range:NSMakeRange(headerLength, textLength - headerLength)];
    
    
    [textStorage appendAttributedString:as];
}

- (void)displayErrorPacket:(ErrorPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSString *s = [NSString stringWithFormat:@"[=Error=] %@\n", p.errorText];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:s];
    NSUInteger textLength = [as length];
    NSUInteger headerLength = 9; // [=Error=]
    
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:NSMakeRange(0, textLength)];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:NSMakeRange(0, textLength)];
    
    [as addAttribute:NSForegroundColorAttributeName
               value:_errorTextColor
               range:NSMakeRange(0, headerLength)];
    [as addAttribute:kTextStyle
               value:kTextStyleErrorHeader
               range:NSMakeRange(0, headerLength)];
    
    [as addAttribute:NSForegroundColorAttributeName
               value:_errorTextColor
               range:NSMakeRange(headerLength, textLength - headerLength)];
    [as addAttribute:kTextStyle
               value:kTextStyleErrorText
               range:NSMakeRange(headerLength, textLength - headerLength)];
    
    [textStorage appendAttributedString:as];
}

- (void)displayGroupHandling:(CommandOutputPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:@"Group     ## S  Moderator    \n"];
    
    const NSRange textRange = NSMakeRange(0, [as length]);
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_commandTextColor
               range:textRange];
    [as addAttribute:kTextStyle
               value:kTextStyleCommandText
               range:textRange];
    [textStorage appendAttributedString:as];
}

- (void)displayWhoHeader:(CommandOutputPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
                                     initWithString:@"   Nickname      Idle      Sign-on  Account\n"];

    const NSRange textRange = NSMakeRange(0, [as length]);
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_commandTextColor
               range:textRange];
    [as addAttribute:kTextStyle
               value:kTextStyleCommandText
               range:textRange];
    [textStorage appendAttributedString:as];
}

- (void)displayWhoListing:(CommandOutputPacket *)p
{
    const NSTextStorage *textStorage = self.outputTextView.textStorage;
    
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
    
    [ms appendFormat:@" %@ ", [DateTimeUtils formatElapsedTime:[p idleTime]]];
    [ms appendFormat:@"%@ ", [DateTimeUtils formatEventTime:[p signOnTime]]];
    [ms appendFormat:@"%@@%@\n", p.username, p.hostname];
    
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:ms];
    const NSRange textRange = NSMakeRange(0, [as length]);
    const NSRange nickRange = NSMakeRange(1, [[p nickname] length]);
    [as addAttribute:NSFontAttributeName
               value:_outputFont
               range:textRange];
    [as addAttribute:NSBackgroundColorAttributeName
               value:_backgroundColor
               range:textRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_commandTextColor
               range:textRange];
    [as addAttribute:kTextStyle
               value:kTextStyleCommandText
               range:textRange];
    [as addAttribute:NSLinkAttributeName
               value:[p nickname]
               range:nickRange];
    [as addAttribute:NSForegroundColorAttributeName
               value:_openNickColor
               range:nickRange];
    [as addAttribute:kTextStyle
               value:kTextStyleOpenNick
               range:nickRange];
    
    [textStorage appendAttributedString:as];
}

- (void)displayCommandOutputPacket:(CommandOutputPacket *)p
{
    if ([p.outputType compare:@"gh"] == NSOrderedSame)
    {
        [self displayGroupHandling:p];
    }
    else if ([p.outputType compare:@"wh"] == NSOrderedSame)
    {
        [self displayWhoHeader:p];
    }
    else if ([p.outputType compare:@"wl"] == NSOrderedSame)
    {
        [self displayWhoListing:p];
    }
    else
    {
        [self displayText:[NSString stringWithFormat:@"%@\n", p.output]
            withTextStyle:kTextStyleCommandText];
    }
}

- (void)fireTimer:(id)arg
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    NSTimeInterval start = [_connectedTime timeIntervalSince1970];
    NSTimeInterval elapsedTime = now - start;
    NSString *elapsedText = [DateTimeUtils formatSimpleTime:elapsedTime];
    [self.connectionTimeLabel setStringValue:[NSString stringWithFormat:@"Connected: %@", elapsedText]];
    
    start = [_lastMessageSentAt timeIntervalSince1970];
    NSTimeInterval idleTime = now - start;
    NSString *idleText = [DateTimeUtils formatSimpleTime:idleTime];
    [self.idleTimeLabel setStringValue:[NSString stringWithFormat:@"Idle: %@", idleText]];
}
         
- (void)setupPacketHandlers
{
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSValue valueWithPointer:@selector(displayBeepPacket:)], [BeepPacket className],
                       [NSValue valueWithPointer:@selector(displayCommandOutputPacket:)], [CommandOutputPacket className],
                       [NSValue valueWithPointer:@selector(displayErrorPacket:)], [ErrorPacket className],
                       [NSValue valueWithPointer:@selector(displayExitPacket:)], [ExitPacket className],
                       [NSValue valueWithPointer:@selector(displayOpenPacket:)], [OpenPacket className],
                       [NSValue valueWithPointer:@selector(displayPersonalPacket:)], [PersonalPacket className],
                       [NSValue valueWithPointer:@selector(displayPingPacket:)], [PingPacket className],
                       [NSValue valueWithPointer:@selector(displayProtocolPacket:)], [ProtocolPacket className],
                       [NSValue valueWithPointer:@selector(displayStatusPacket:)], [StatusPacket className],
                       nil];
    _packetHandlers = d;
}

- (void)handlePacket:(const ICBPacket *)packet
{
    SEL selector = [[_packetHandlers valueForKey:[packet className]] pointerValue];
    if (selector)
    {
        NSTextStorage *textStorage = [self.outputTextView textStorage];
        [textStorage beginEditing];

        [self displayMessageTimestamp];

        SuppressPerformSelectorLeakWarning([self performSelector:selector
                                                      withObject:packet]);
        
        [self trimBuffer:textStorage toLines:kOutputScrollbackSize];
        
        [textStorage endEditing];
        [self scrollToEnd];
    }
}

- (void)trimBuffer:(const NSTextStorage *)textStorage
           toLines:(const NSUInteger)maxLines
{
    const NSArray *paragraphs = [textStorage paragraphs];
    const NSUInteger n = [paragraphs count];
    if (n >= maxLines)
    {
        NSUInteger len = 0;
        for (NSUInteger i  = 0; i < n - maxLines; i++)
        {
            len += [[paragraphs objectAtIndex:i] length];
        }
        const NSRange r = NSMakeRange(1, len);
        [textStorage deleteCharactersInRange:r];
    }
}

- (void)scrollToEnd
{
    NSView *superview = [self.outputTextView superview];
    if ([superview isKindOfClass:[NSClipView class]])
    {
        NSClipView *clipView = (NSClipView *)superview;
        NSPoint scrollPoint = NSMakePoint(0, [self.outputTextView
                                              frame].size.height);
        [clipView scrollToPoint:[clipView constrainScrollPoint:scrollPoint]];
        [[clipView superview] reflectScrolledClipView:clipView];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([keyPath compare:kUseTransparency] == NSOrderedSame)
    {
        BOOL isTransparent = [[change valueForKey:@"new"] boolValue];
        [self setTransparency:isTransparent];
    }
    else if ([keyPath compare:kOpacityLevel] == NSOrderedSame)
    {
        BOOL isTransparent = [[userDefaults valueForKey:kUseTransparency] boolValue];
        if (isTransparent)
        {
            [self setTransparency:isTransparent];
        }
    }
}

- (void)clientNotify:(NSNotification *)notification
{
    if ([[notification name] compare:kICBClient_packet] == NSOrderedSame)
    {
        const ICBPacket *packet = [notification object];
        [self handlePacket:packet];
    }
    else if ([[notification name] compare:kICBClient_connecting] == NSOrderedSame)
    {
        [self.connectionStatusLabel setStringValue:@"Connecting"];

        [self.progressIndicator setHidden:NO];
        [self.progressIndicator startAnimation:self];
    }
    else if ([[notification name] compare:kICBClient_connectfailed] == NSOrderedSame)
    {
        [self.connectionStatusLabel setStringValue:@"Connect Failed"];
        [self.progressIndicator stopAnimation:self];
        [self.progressIndicator setHidden:YES];
    }
    else if ([[notification name] compare:kICBClient_connected] == NSOrderedSame)
    {
        [self.connectionStatusLabel setStringValue:@"Connected"];

        [self.progressIndicator stopAnimation:self];
        [self.progressIndicator setHidden:YES];
        
        [self.idleTimeLabel setHidden:NO];
        [self.connectionTimeLabel setHidden:NO];
        
        _connectedTime = [NSDate date];
        _lastMessageSentAt = [NSDate date];
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(fireTimer:)
                                                    userInfo:nil
                                                     repeats:YES];
    }
    else if ([[notification name] compare:kICBClient_disconnecting] == NSOrderedSame)
    {
        [self.connectionStatusLabel setStringValue:@"Disconnected"];
    }
    else if ([[notification name] compare:kICBClient_disconnected] == NSOrderedSame)
    {
        [self.connectionStatusLabel setStringValue:@"Disconnected"];
        
        [self.timer invalidate];
        self.timer = nil;
        [self.idleTimeLabel setHidden:YES];
        [self.connectionTimeLabel setHidden:YES];
    }
    else if ([[notification name] compare:kICBClient_loginOK] == NSOrderedSame)
    {
        // NO-OP
    }
}

@end
