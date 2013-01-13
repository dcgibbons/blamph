//
//  UIController.h
//  Blamph
//
//  Created by Chad Gibbons on 11/15/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <URLKit/URLKit.h>

#import "MainWindow.h"
#import "ICBClient.h"

@interface UIController : NSObject <NSTextViewDelegate, URLShorteningObserver>

@end
