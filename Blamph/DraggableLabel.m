//
//  DraggableLabel.m
//  Blamph
//
//  Created by Chad Gibbons on 11/15/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "DraggableLabel.h"

@implementation DraggableLabel

- (BOOL)mouseDownCanMoveWindow
{
    NSLog(@"mouseDownCanMoveWindow!");
    return YES;
}
@end
