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
#import "PongPacket.h"
#import "ProtocolPacket.h"
#import "OpenPacket.h"
#import "StatusPacket.h"
#import "NicknameHistory.h"

#define kICBClient_connecting       @"ICBClient:connecting"
#define kICBClient_connected        @"ICBClient:connected"
#define kICBClient_disconnecting    @"ICBClient:disconnecting"
#define kICBClient_disconnected     @"ICBClient:disconnected"
#define kICBClient_packet           @"ICBClient:packet"
#define kICBClient_loginOK          @"ICBClient:loginOK"

@interface ICBClient : NSObject <NSStreamDelegate>
{
@private
    enum { DISCONNECTED, DISCONNECTING, CONNECTING, CONNECTED } connectionState;

    NSString *nickname;
    NSString *initialGroup;
    NSString *password;
    
    uint8_t packetLength, bufferPos;
    uint8_t *packetBuffer;
    
    NSMutableArray *inputQueue;
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

@property (nonatomic, readonly) NSArray *groups;
@property (nonatomic, readonly) NSArray *users;
@property (nonatomic, retain) NSInputStream *istream;
@property (nonatomic, retain) NSOutputStream *ostream;
@property (nonatomic, retain) NicknameHistory *nicknameHistory;

- (id)init;

- (BOOL)isConnected;
- (void)changeConnectingState:(int)newState;

- (void)connectUsingHostname:(NSString *)hostname
                     andPort:(UInt32)port
                 andNickname:(NSString *)userNickname
                   intoGroup:(NSString *)initalGroup
                withPassword:(NSString *)password;

- (void)disconnect;

- (void)sendPacket:(ICBPacket *)packet;
- (void)sendOpenMessage:(NSString *)msg;
- (void)sendPersonalMessage:(NSString *)nick withMsg:(NSString *)msg;
- (void)sendWriteMessage:(NSString *)nick withMsg:(NSString *)msg;

@end