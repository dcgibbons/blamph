//
//  ICBClient.m
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ICBClient.h"

@implementation ICBClient

- (id)initWithServer:(ServerDefinition *)userServerDefinition andNickname:(NSString *)userNickname
{
    if (self = [super init])
    {
        nickname = userNickname;
        serverDefinition = userServerDefinition;
        
        packetBuffer = malloc(MAX_PACKET_SIZE);
        chatGroups = [NSMutableArray arrayWithCapacity:100];
        chatUsers = [NSMutableArray arrayWithCapacity:500];
        
        bytesReceived = 0;
        bytesSent = 0;
        packetsReceived = 0;
        packetsSent = 0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePacket:) name:@"ICBPacket" object:nil];
        
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef)@"localhost", 7326, &readStream, &writeStream);
        if (readStream && writeStream) {
            CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            
            istream = (__bridge_transfer NSInputStream *)readStream;
            [istream setDelegate:self];
            [istream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [istream open];
            
            ostream = (__bridge_transfer NSOutputStream *)writeStream;
            [ostream setDelegate:self];
            [ostream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [ostream open];
        }
        
        if (readStream)
            CFRelease(readStream);
        
        if (writeStream)
            CFRelease(writeStream); 
    }
    return self;
}

- (NSString *)groups
{
    return [NSArray arrayWithArray:chatGroups];
}

- (NSString *)users
{
    return [NSArray arrayWithArray:chatUsers];
}

- (void)handlePacket:(NSNotification *)notification
{
    ICBPacket *packet = [notification object];
    DLog("handlePacket: packet received! %@", packet);
    packetsReceived++;

    if ([packet isKindOfClass:[CommandOutputPacket class]])
    {
        [self handleCommandOutputPacket:(CommandOutputPacket *)packet];
    }
    else if ([packet isKindOfClass:[ExitPacket class]])
    {
        // TODO
    }
    else if ([packet isKindOfClass:[PingPacket class]])
    {
        // TODO
    }
    else if ([packet isKindOfClass:[ProtocolPacket class]])
    {
        [self handleProtocolPacket:(ProtocolPacket *)packet];
    }
    else if ([packet isKindOfClass:[ErrorPacket class]])
    {
        [self handleErrorPacket:(ErrorPacket *)packet];
    }
    else if ([packet isKindOfClass:[LoginPacket class]])
    {
        [self handleLoginPacket:(LoginPacket *)packet];
    }
}

- (void)handleCommandOutputPacket:(CommandOutputPacket *)packet
{
    DLog(@"CommandOutputPacket!\n%@", [[packet data] hexDump]);
    NSString *outputType = [packet outputType];
    
    if (clientState == kParsingWhoListing)
    {
        if ([outputType compare:@"gh"] == 0)
        {
            // NO-OP
        }
        else if ([outputType compare:@"wg"] == 0)
        {
            DLog(@"WTF?!");
        }
        else if ([outputType compare:@"wh"] == 0)
        {
            // NO-OP
        }
        else if ([outputType compare:@"wl"] == 0)
        {
            NSString *chatUser = [packet getFieldAtIndex:2];
            [chatUsers addObject:chatUser];
        }
        else if ([outputType compare:@"co"] == 0)
        {
            // When doing a full who listing, a CommandOutput output type will appear in the format of
            // Total: %d user(s in %d group(s) to designate the end of the who listing
            if ([[packet getFieldAtIndex:1] compare:@"Total" options:0 range:NSMakeRange(0, 5)] == 0) 
            {
                DLog(@"Who Listing Complete!");
                DLog(@"Groups=%@", chatGroups);
                DLog(@"Users=%@", chatUsers);
            }
            else if ([[packet getFieldAtIndex:1] compare:@"Group: " options:0 range:NSMakeRange(0, 7)] == 0)
            {
                NSString *chatGroup = [[[packet getFieldAtIndex:1] substringWithRange:NSMakeRange(7, 8)] 
                                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                [chatGroups addObject:chatGroup];
            }
        }
    }
}

- (void)handleErrorPacket:(ErrorPacket *)packet
{
    DLog(@"[=Error=] %@", [packet errorText]);
}

- (void)handleLoginPacket:(LoginPacket *)packet
{
    DLog(@"Login OK - sending who command");
    // TODO: reconnectNeeded = false
    
    CommandPacket *whoPacket = [[CommandPacket alloc] initWithCommand:@"w" optionalArgs:@""];
    [self sendPacket:whoPacket];
    
    clientState = kParsingWhoListing;
    [chatGroups removeAllObjects];
    [chatUsers removeAllObjects];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ICBClient:loginOK" object:self];
}

- (void)handleProtocolPacket:(ProtocolPacket *)packet
{
    // TODO: check protocol packet version
    
    NSString *id = nickname;
    NSString *nick = nickname;
    NSString *group = @"";
    NSString *command = @"login";
    NSString *passwd = @"";

    LoginPacket *loginPacket = [[LoginPacket alloc] initWithUserDetails:id 
                                                                   nick:nick 
                                                                  group:group 
                                                                command:command 
                                                               password:passwd];
    [self sendPacket:loginPacket];  
}

- (void)sendPacket:(ICBPacket *)packet
{
    NSData *data = [packet data];
    DLog(@"Sending Packet!!!\n%@", [data hexDump]);
    packetsSent++;

    uint8_t l = [data length];
    NSInteger written = [ostream write:&l maxLength:sizeof(l)];
    DLog(@"wrote %d bytes", written);
    NSAssert(written == sizeof(l), @"unable to write packet length");
    written = [ostream write:[data bytes] maxLength:l];
    DLog(@"wrote %d bytes", written);
    NSAssert(written == l, @"unable to write packet data");
}

- (void)handleInputStream:(NSInputStream *)stream
{
    // NOTE: it appears from reviewing http://www.opensource.apple.com/source/CFNetwork/CFNetwork-129.9/Stream/CFSocketStream.c
    // that the internal CFStream buffer sizes are 32 KB, so we don't need additional buffering logic in this class.
    
    while ([stream hasBytesAvailable])
    {
        if (readState == kWaitingForPacket)
        {
            NSInteger len = [stream read:&packetLength maxLength:sizeof(packetLength)];
            if (len < 0)
            {
                DLog(@"Error reading from input stream!");
            }
            else if (len == 0)
            {
                DLog(@"0 bytes read from input stream!");
            }
            else
            {
                DLog(@"new packet detected, packetLength=%u", packetLength);
                bytesReceived += len;
                bufferPos = 0;
                readState = kReadingPacket;
            }
        }
        else if (readState == kReadingPacket)
        {
            NSInteger len = [stream read:&packetBuffer[bufferPos] maxLength:packetLength - bufferPos];
            if (len < 0)
            {
                DLog(@"Error reading from input stream!");
            }
            else if (len == 0)
            {
                DLog(@"0 bytes read from input stream!");
            }
            else
            {
                DLog(@"%d bytes read from input stream!", len);
                bytesReceived += len;
                bufferPos += len;
                if (bufferPos < packetLength)
                {
                    DLog(@"packet not fully read, need %u more bytes", packetLength - bufferPos);
                }
                else
                {
                    NSData *packetData = [NSData dataWithBytes:packetBuffer length:packetLength];
                    ICBPacket *packet = [ICBPacket packetWithBuffer:packetData];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ICBPacket" object:packet];
                    
                    readState = kWaitingForPacket;
                }
            }
        }
    }
}

#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            DLog(@"NSStreamEventOpenCompleted");
            readState = kWaitingForPacket;
            clientState = kReady;
            break;
            
        case NSStreamEventHasBytesAvailable:
            DLog(@"NSStreamEventHasBytesAvailable");
            [self handleInputStream:(NSInputStream *)theStream];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            DLog(@"NSStreamEventHasSpaceAvailable");
            break;
            
        case NSStreamEventErrorOccurred:
            DLog(@"NSStreamEventErrorOccurred");
            break;
            
        case NSStreamEventEndEncountered:
            DLog(@"NSStreamEventEndEncountered");
            break;
            
        default:
            break;
    }
}

@end
