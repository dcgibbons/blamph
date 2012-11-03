//
//  ICBData.h
//  Blamph
//
//  Created by Chad Gibbons on 7/9/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ICBData : NSObject

@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic) uint16_t serverPort;
@property (nonatomic, copy) NSMutableArray *groups;
@property (nonatomic, copy) NSMutableArray *users;
@property (nonatomic, copy) NSMutableDictionary *messages;

@end
