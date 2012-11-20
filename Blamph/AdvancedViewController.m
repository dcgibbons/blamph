//
//  AdvancedViewController.m
//  Blamph
//
//  Created by Chad Gibbons on 11/17/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "AdvancedViewController.h"

@interface AdvancedViewController ()

@end

@implementation AdvancedViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Initialization code here.
    }
    
    return self;
}

-(NSString *)identifier
{
    return @"Advanced";
}

-(NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:NSImageNameAdvanced];
}

-(NSString *)toolbarItemLabel
{
    return @"Advanced";
}

@end
