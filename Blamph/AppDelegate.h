//
//  AppDelegate.h
//  Blamph
//
//  Created by Chad Gibbons on 10/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ICBClient.h"

@interface AppDelegate : NSObject
    <NSApplicationDelegate, NSTextViewDelegate, NSTextViewDelegate>
{
    NSMutableArray *servers;
    ICBClient *client;
}

@property (nonatomic, retain) IBOutlet NSTextView *inputTextView;
@property (nonatomic, retain) IBOutlet NSTextView *outputTextView;
@property (assign) IBOutlet NSWindow *window;

- (void)submitTextInput:(NSString *)input;

- (void)displayText:(NSString *)text;

- (BOOL)textView:(NSTextView *)aTextView
   clickedOnLink:(id)link
         atIndex:(NSUInteger)charIndex;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

- (void)clientNotify:(NSNotification *)notification;
- (void)handlePacket:(NSNotification *)notification;

@end
