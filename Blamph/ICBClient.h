//
//  ICBClient.h
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICBPacket.h"
#import "BeepPacket.h"
#import "CommandPacket.h"
#import "CommandOutputPacket.h"
#import "ErrorPacket.h"
#import "ExitPacket.h"
#import "LoginPacket.h"
#import "PersonalPacket.h"
#import "PingPacket.h"
#import "ProtocolPacket.h"
#import "OpenPacket.h"
#import "StatusPacket.h"
#import "ServerDefinition.h"

@interface ICBClient : NSObject <NSStreamDelegate>
{
@private
    ServerDefinition *serverDefinition;
    NSString *nickname;
    
    uint8_t packetLength, bufferPos;
    uint8_t *packetBuffer;
    
    NSMutableArray *outputQueue;
    
    enum { kWaitingForPacket, kReadingPacket } readState;
    
    enum { kReady, kParsingWhoListing } clientState;
    
    NSMutableArray *chatGroups;
    NSMutableArray *chatUsers;
    
    // statistics
    NSUInteger bytesReceived;
    NSUInteger bytesSent;
    NSUInteger packetsReceived;
    NSUInteger packetsSent;
}

- (id)initWithServer:(ServerDefinition *)serverDefinition andNickname:(NSString *)nickname;
- (void)disconnect;

- (void)handlePacket:(NSNotification *)notification;
- (void)handleCommandOutputPacket:(CommandOutputPacket *)packet;
- (void)handleErrorPacket:(ErrorPacket *)packet;
- (void)handleLoginPacket:(LoginPacket *)packet;
- (void)handleProtocolPacket:(ProtocolPacket *)packet;

- (void)sendPacket:(ICBPacket *)packet;
- (void)handleInputStream:(NSInputStream *)stream;
- (void)handleOutputStream:(NSOutputStream *)stream;

- (void)sendOpenMessage:(NSString *)msg;
- (void)sendPersonalMessage:(NSString *)nick withMsg:(NSString *)msg;
- (void)sendWriteMessage:(NSString *)nick withMsg:(NSString *)msg;

@property (nonatomic, readonly) NSArray *groups;
@property (nonatomic, readonly) NSArray *users;
@property (nonatomic, retain) NSInputStream *istream;
@property (nonatomic, retain) NSOutputStream *ostream;

@end