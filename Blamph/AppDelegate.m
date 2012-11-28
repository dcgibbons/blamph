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
@synthesize preferences = _preferences;

+ (void)initialize
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    // load the default values for the user defaults
    NSArray *servers = [NSArray arrayWithObject:
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         @"default.icb.net", @"hostname",
                         [NSNumber numberWithInt:7326], @"port",
                         nil]];
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       servers, @"servers",
                       [NSNumber numberWithUnsignedLong:0L], @"defaultServer",
                       [NSNumber numberWithBool:YES], @"sendKeepAlives",
                       [NSNumber numberWithDouble:60.0], @"keepAliveInterval",
                       nil];
    [userDefaults registerDefaults:d];
    
    DLog(@"NSUserDefaults - default values set");
}

- (id)init
{
    if (self = [super init])
    {
    }
    return self;
}

- (void)awakeFromNib
{
    DLog(@"ApplicationDelegate awakeFromNib");
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

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
    
    NSUInteger server = [[userDefaults valueForKey:@"defaultServer"] unsignedLongValue];
    NSDictionary *serverDefinition = [[userDefaults arrayForKey:@"servers"]
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
    [self.client disconnect];
}

- (IBAction)preferences:(id)sender
{
    if (_preferences == nil)
    {
        NSBundle *mainBundle = [NSBundle mainBundle];
        GeneralViewController *general = [[GeneralViewController alloc]
                                          initWithNibName:@"GeneralViewController"
                                          bundle:mainBundle];
        NSViewController *advanced = [[AdvancedViewController alloc]
                                      initWithNibName:@"AdvancedViewController"
                                      bundle:mainBundle];
        NSArray *views = [NSArray arrayWithObjects:general, advanced, nil];
        self.preferences = [[MASPreferencesWindowController alloc]
                            initWithViewControllers:views
                            title:@"Preferences"];
    }
    
    [self.preferences showWindow:self];
}


@end
