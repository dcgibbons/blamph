//
//  AppDelegate.h
//  Blamph
//
//  Created by Chad Gibbons on 07/05/2012.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ICBClient.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
}

@property (strong, nonatomic) UIWindow *window;
//@property (strong, nonatomic) ICBClient *client;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
