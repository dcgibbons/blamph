//
//  GeneralViewController.m
//  Blamph
//
//  Created by Chad Gibbons on 11/17/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "GeneralViewController.h"

@interface GeneralViewController ()

@end

@implementation GeneralViewController

@synthesize serversTableView = _serversTableView;
@synthesize serverDefinitions = _serverDefinitions;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)awakeFromNib
{
    [_serverDefinitions addObserver:self
                         forKeyPath:@"arrangedObjects.hostname"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];

    [_serverDefinitions addObserver:self
                         forKeyPath:@"arrangedObjects.port"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];

    [_serverDefinitions addObjects:[[NSUserDefaults standardUserDefaults]
                                    arrayForKey:@"servers"]];
}

-(NSString *)identifier
{
    return @"General";
}

-(NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

-(NSString *)toolbarItemLabel
{
    return @"General";
}

- (IBAction)addServer:(id)sender
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              @"unknown", @"hostname",
                              [NSNumber numberWithInt:7326], @"port",
                              nil];
    [self.serverDefinitions addObject:d];
}

- (IBAction)removeServer:(id)sender
{
    NSIndexSet *selections = [self.serverDefinitions selectionIndexes];
    [self.serverDefinitions removeObjectsAtArrangedObjectIndexes:selections];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:[self.serverDefinitions arrangedObjects]
                    forKey:@"servers"];
}

@end
