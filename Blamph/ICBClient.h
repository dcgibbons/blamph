//
//  ICBClient.h
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICBPacket.h"
#import "CommandPacket.h"
#import "CommandOutputPacket.h"
#import "ErrorPacket.h"
#import "ExitPacket.h"
#import "LoginPacket.h"
#import "PingPacket.h"
#import "ProtocolPacket.h"

@interface ICBClient : NSObject <NSStreamDelegate>
{
@private
    NSInputStream *istream;
    NSOutputStream *ostream;
    
    uint8_t packetLength, bufferPos;
    uint8_t *packetBuffer;
    
    enum { kWaitingForPacket, kReadingPacket } readState;
    
    enum { kReady, kParsingWhoListing } clientState;
    
    NSMutableArray *chatGroups;
    NSMutableArray *chatUsers;
}

- (id)init;
- (void)handlePacket:(NSNotification *)notification;
- (void)handleCommandOutputPacket:(CommandOutputPacket *)packet;
- (void)handleErrorPacket:(ErrorPacket *)packet;
- (void)handleLoginPacket:(LoginPacket *)packet;
- (void)handleProtocolPacket:(ProtocolPacket *)packet;

- (void)sendPacket:(ICBPacket *)packet;
- (void)handleInputStream:(NSInputStream *)stream;

@end
