//
//  UIController.h
//  Blamph
//
//  Created by Chad Gibbons on 11/15/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MainWindow.h"
#import "ICBClient.h"

@interface UIController : NSObject <NSTextViewDelegate>

@property (nonatomic, retain) IBOutlet ICBClient *client;

@property (nonatomic, retain) IBOutlet NSMenuItem *connectMenuItem;
@property (nonatomic, retain) IBOutlet NSMenuItem *disconnectMenuItem;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemCopy;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemPaste;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemToggleStatusBar;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemDefaultColorScheme;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemOldSchoolColorScheme;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemUseTransparency;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemIncreaseFontSize;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemDefaultFontSize;
@property (nonatomic, retain) IBOutlet NSMenuItem *menuItemDecreaseFontSize;

@property (nonatomic, retain) IBOutlet NSSplitView *splitView;
@property (nonatomic, retain) IBOutlet NSScrollView *outputScrollView;
@property (nonatomic, retain) IBOutlet NSScrollView *inputScrollView;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (nonatomic, retain) IBOutlet NSView *statusBarView;
@property (nonatomic, retain) IBOutlet NSTextField *connectionStatusLabel;
@property (nonatomic, retain) IBOutlet NSTextField *connectionTimeLabel;
@property (nonatomic, retain) IBOutlet NSTextField *idleTimeLabel;

@property (nonatomic, retain) IBOutlet NSProgressIndicator *progressIndicator;

@property (nonatomic, retain) IBOutlet NSTextView *inputTextView;
@property (nonatomic, retain) IBOutlet NSTextView *outputTextView;

@property (nonatomic, retain) IBOutlet MainWindow *window;

@property (nonatomic, retain) NSTimer *timer;

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;

- (void)submitTextInput:(NSString *)input;

- (void)displayText:(NSString *)text
      withTextStyle:(NSString *)textStyle;

- (BOOL)textView:(NSTextView *)aTextView
   clickedOnLink:(id)link
         atIndex:(NSUInteger)charIndex;

- (IBAction)selectAll:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)pasteSpecial:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)selectColorScheme:(id)sender;
- (IBAction)changeFontSize:(id)sender;

- (void)clientNotify:(NSNotification *)notification;

@end
