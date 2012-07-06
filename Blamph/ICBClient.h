//
//  ICBClient.h
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICBPacket.h"
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
    
    NSMutableData *inputBuffer;
    NSMutableData *outputBuffer;

    uint8_t packetLength;
    NSUInteger bytesRead;
    
    enum { kWaitingForPacket, kReadingPacket } readState;
}

- (id)init;
- (void)handlePacket:(NSNotification *)notification;
- (void)handleErrorPacket:(ErrorPacket *)packet;
- (void)handleLoginPacket:(LoginPacket *)packet;
- (void)handleProtocolPacket:(ProtocolPacket *)packet;

- (void)sendPacket:(ICBPacket *)packet;
 - (void)flushOutputBuffer;

@end
