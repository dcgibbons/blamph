//
//  GeneralViewController.h
//  Blamph
//
//  Created by Chad Gibbons on 11/17/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MASPreferencesViewController.h"

@interface GeneralViewController : NSViewController <MASPreferencesViewController>

@property (nonatomic, retain) IBOutlet NSTableView *serversTableView;
@property (nonatomic, retain) IBOutlet NSArrayController *serverDefinitions;

- (IBAction)addServer:(id)sender;
- (IBAction)removeServer:(id)sender;

@end
