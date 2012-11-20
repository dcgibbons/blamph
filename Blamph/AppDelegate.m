//
//  AppDelegate.m
//  Blamph
//
//  Created by Chad Gibbons on 10/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "GeneralViewController.h"
#import "AdvancedViewController.h"

@implementation AppDelegate

@synthesize client = _client;
@synthesize preferencesWindowController = _preferencesWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    // load the default values for the user defaults
    NSArray *s = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"default.icb.net", @"hostname",
                                           [NSNumber numberWithInt:7326], @"port", nil]];
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:s, @"servers", nil];
    [userDefaults registerDefaults:d];

    NSString *nickname = [userDefaults stringForKey:@"nickname"];
    if (nickname == nil || [nickname length] < 1)
    {
        [self preferences:self];
    }
}

- (IBAction)connect:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *nickname = [userDefaults stringForKey:@"nickname"];
    NSString *initialGroup = [userDefaults stringForKey:@"initialGroup"];
    NSString *password = [userDefaults stringForKey:@"password"];
    
    NSUInteger server = 0; // grab from preferences selection
    NSDictionary *serverDefinition = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"servers"]
                                      objectAtIndex:server];
    if (serverDefinition != nil)
    {
        [self.client connectUsingHostname:[serverDefinition valueForKey:@"hostname"]
                                  andPort:[[serverDefinition valueForKey:@"port"] intValue]
                                      andNickname:nickname
                                        intoGroup:initialGroup
                                     withPassword:password];
    }
}

- (IBAction)disconnect:(id)sender
{
    DLog(@"disconnect action");
    [self.client disconnect];
}

- (IBAction)preferences:(id)sender
{
    if (_preferencesWindowController == nil)
    {
        GeneralViewController *generalViewController = [[GeneralViewController alloc]
                                                   initWithNibName:@"GeneralViewController" bundle:[NSBundle mainBundle]];
        NSViewController *advancedViewController = [[AdvancedViewController alloc]
                                                    initWithNibName:@"AdvancedViewController" bundle:[NSBundle mainBundle]];
        NSArray *views = [NSArray arrayWithObjects:generalViewController,
                          advancedViewController, nil];
        self.preferencesWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:views
                                                                                                     title:@"Preferences"];
    }
    
    [self.preferencesWindowController showWindow:self];
}

@end
