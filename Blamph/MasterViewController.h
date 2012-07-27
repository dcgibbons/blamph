//
//  MasterViewController.h
//  Blamph
//
//  Created by Chad Gibbons on 7/24/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ICBClient.h"

@interface MasterViewController : UIViewController <UIPickerViewDelegate, 
                                                    UIPickerViewDataSource,
                                                    UITextFieldDelegate>
{
    NSManagedObjectContext *_managedObjectContext;
    UITextField *_nicknameField;
    UITextField *_serverField;
    
    // TODO: these are data items and don't belong here
    NSMutableArray *servers;
    NSString *nickname;
    NSUInteger server;
    
    ICBClient *client;
}

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) IBOutlet UITextField *nicknameField;
@property (nonatomic, retain) IBOutlet UITextField *serverField;
@property (nonatomic, retain) ICBClient *client;

@end
