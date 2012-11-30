//
//  NSString+StringUtils.h
//  Blamph
//
//  Created by Chad Gibbons on 11/29/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (StringUtils)

- (NSArray *)smartSplitByLength:(NSUInteger)length;

@end
