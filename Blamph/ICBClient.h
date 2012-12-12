//
//  ICBClient.h
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ICBProtocolFramework/ICBPacket.h>
#import "NicknameHistory.h"

/*!
 @class ICBClient
 @discussion This class is the primary client for a connection to an ICB server.
 The class controls the communication, protocol management and basic message
 handling with an ICB server.
 
 Clients of this class should register for notifications using the constants
 defined within. This client class will send out notifications based upon the
 internal state of the client and whenever data is received from the server.
 
 Sending packages and messages must be done with the methods provided by this
 class. The sendOpenMessage, sendPersonalMessage and sendWriteMessage are
 helper functions that allow messages larger than the maximum message size to
 be split up and sent as multiple packages automatically.
 */
@interface ICBClient : NSObject

@property (nonatomic, readonly) NicknameHistory *nicknameHistory;
@property (nonatomic, readonly) NSString *currentGroupName;
@property (nonatomic, readonly) NSMutableArray *currentGroupUsers;

- (id)init;

/*!
 @methodgroup Connection Management
 */

/*!
 Determines if the client is currently connected to an ICB server.
 @result
 YES if the client is currently connected, NO otherwise.
 */
- (BOOL)isConnected;

/*!
 Attempts to connect to an ICB server. This method is asynchronous and will
 return immediately. Once connected, or failed, the appropriate notification
 will be sent out.
 @param hostname
    the hostname or IP address of the ICB server
 @param port
    the TCP port of the ICB server
 @param userNickname
    the initial nickname of the user
 @param initialGroup
    the initial group of the user, or nil to default to the server's choice
 @param password
    the password to use for automatic user registration, or nil to skip
 */
- (void)connectUsingHostname:(NSString *)hostname
                     andPort:(UInt32)port
                 andNickname:(NSString *)userNickname
            withAlterateNick:(NSString *)alternateNick
                   intoGroup:(NSString *)initalGroup
                withPassword:(NSString *)password;

/*!
 Disconnects from the ICB server. This method is asynchronous and will return
 immediately. Once disconnected, or failed, the appropriate notification will
 be sent out.
 */
- (void)disconnect;

/*!
 @methodgroup Message Sending
 */

/*!
 Sends a specific ICB packet to the server. This method is asynchronous and
 will return immediately. The packet is queued for transmission when the
 outbound socket connection has available space.
 @param packet
    the packet to send
 */
- (void)sendPacket:(ICBPacket *)packet;

/*!
 Sends a text string as an open message to the user's current group. If the text
 is too long it will automatically span multiple ICB packets as appropriate.
 @param msg
    the text message to send
 */
- (void)sendOpenMessage:(NSString *)msg;

/*!
 Sends a text string as a personal message to the specified user. If the text
 is too long it will automatically span multiple ICB packets as appropriate.
 @param nick
    the user to send the message to
 @param msg
    the text message to send
 */
- (void)sendPersonalMessage:(NSString *)nick withMsg:(NSString *)msg;

/*!
 Sends a text string as a persistent 'write' message to the specified user. If
 the text is too long it will automatically span multiple ICB packets as 
 appropriate.
 @param nick
    the user to write the message to
 @param msg
    the text message to send
 */
- (void)sendWriteMessage:(NSString *)nick withMsg:(NSString *)msg;

#define kICBClient_connecting       @"ICBClient:connecting"
#define kICBClient_connectfailed    @"ICBClient:connectfailed"
#define kICBClient_connected        @"ICBClient:connected"
#define kICBClient_disconnecting    @"ICBClient:disconnecting"
#define kICBClient_disconnected     @"ICBClient:disconnected"
#define kICBClient_packet           @"ICBClient:packet"
#define kICBClient_loginOK          @"ICBClient:loginOK"
#define kICBClient_groupChange      @"ICBClient:groupChange"
#define kICBClient_groupUsersChange @"ICBClient:groupUsersChange"

@end