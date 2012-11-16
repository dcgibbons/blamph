//
//  AppDelegate.h
//  Blamph
//
//  Created by Chad Gibbons on 10/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ICBClient.h"
#import "MainWindow.h"

@interface AppDelegate : NSObject
    <NSApplicationDelegate, NSTextViewDelegate, NSTextViewDelegate>
{
    enum { DISCONNECTED, DISCONNECTING, CONNECTING, CONNECTED } connectionState;
    
    NSMutableArray *servers;
    ICBClient *client;
    
    NSColor *backgroundColor;
    NSColor *openTextColor;
    NSColor *openNickColor;
    NSColor *personalTextColor;
    NSColor *personalNickColor;
    NSColor *commandTextColor;
    NSColor *errorTextColor;
    NSColor *statusHeaderColor;
    NSColor *statusTextColor;
    
    NSDate *connectedTime;
    NSDate *lastMessageSentAt;
}

@property (nonatomic, retain) IBOutlet NSMenuItem *connectMenuItem;
@property (nonatomic, retain) IBOutlet NSMenuItem *disconnectMenuItem;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemCopy;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemPaste;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemToggleStatusBar;
@property (nonatomic, retain) IBOutlet NSView *statusBarView;
@property (nonatomic, retain) IBOutlet NSTextField *connectionStatusLabel;
@property (nonatomic, retain) IBOutlet NSTextField *connectionTimeLabel;
@property (nonatomic, retain) IBOutlet NSTextField *idleTimeLabel;
@property (nonatomic, retain) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, retain) IBOutlet NSTextView *inputTextView;
@property (nonatomic, retain) IBOutlet NSTextView *outputTextView;
@property (assign) IBOutlet MainWindow *window;
@property (nonatomic, retain) NSTimer *timer;

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;

- (void)submitTextInput:(NSString *)input;

- (void)displayText:(NSString *)text
     withForeground:(NSColor *)foreground
      andBackground:(NSColor *)background;

- (BOOL)textView:(NSTextView *)aTextView
   clickedOnLink:(id)link
         atIndex:(NSUInteger)charIndex;

- (void)changeConnectionState:(int)newState;
- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;

- (void)clientNotify:(NSNotification *)notification;
- (void)handlePacket:(NSNotification *)notification;

@end
