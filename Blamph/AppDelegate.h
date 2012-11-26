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
#import "MASPreferencesWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, retain) IBOutlet ICBClient *client;
@property (nonatomic, retain) MASPreferencesWindowController *preferences;

- (void)awakeFromNib;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)preferences:(id)sender;

@end
