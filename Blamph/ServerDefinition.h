//
//  ServerDefinition.h
//  Blamph
//
//  Created by Chad Gibbons on 7/26/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ServerDefinition : NSObject
{
@private
    NSString *name;
    NSString *hostname;
    NSUInteger port;
}

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *hostname;
@property (nonatomic) NSUInteger port;

- (id)initWithName:(NSString *)name andHostname:(NSString *)hostname andPort:(NSUInteger)port;

@end
