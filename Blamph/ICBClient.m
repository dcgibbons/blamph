//
//  ICBClient.m
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ICBClient.h"

@implementation ICBClient

@synthesize istream, ostream;
@synthesize nicknameHistory;

- (id)init
{
    if (self = [super init])
    {
        connectionState = DISCONNECTED;
        
        packetBuffer = [NSMutableData dataWithCapacity:MAX_PACKET_SIZE];
        inputQueue = [NSMutableArray arrayWithCapacity:100];
        outputQueue = [NSMutableArray arrayWithCapacity:100];
        nicknameHistory = [[NicknameHistory alloc] init];
        
        bytesReceived = 0;
        bytesSent = 0;
        packetsReceived = 0;
        packetsSent = 0;
    }
    return self;
}

- (BOOL)isConnected
{
    return (connectionState == CONNECTED);
}

- (void)changeConnectingState:(int)newState
{
    connectionState = newState;

    NSString *notificationName = nil;
    switch (connectionState)
    {
        case DISCONNECTED:
            notificationName = kICBClient_disconnected;
            break;
        case DISCONNECTING:
            notificationName = kICBClient_disconnecting;
            break;
        case CONNECTING:
            notificationName = kICBClient_connecting;
            break;
        case CONNECTED:
            notificationName = kICBClient_connected;
            break;
    }
    
    if (notificationName != nil)
    {
        NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
        [ns postNotificationName:notificationName object:self];
    }
}

- (void)connectUsingHostname:(NSString *)hostname
                     andPort:(UInt32)port
                 andNickname:(NSString *)userNickname
                   intoGroup:(NSString *)userGroup
                withPassword:(NSString *)userPassword
{
    if ([self isConnected])
    {
        @throw [NSException exceptionWithName:@"illegal state exception"
                                       reason:@"already connected"
                                     userInfo:nil];
    }
    
    [self changeConnectingState:CONNECTING];
    
    nickname = userNickname;
    initialGroup = userGroup;
    password = userPassword;
    
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       (__bridge CFStringRef)hostname,
                                       port,
                                       &readStream,
                                       &writeStream);
    if (readStream && writeStream) {
        CFReadStreamSetProperty(readStream,
                                kCFStreamPropertyShouldCloseNativeSocket,
                                kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream,
                                 kCFStreamPropertyShouldCloseNativeSocket,
                                 kCFBooleanTrue);
        
        // NOTE: we needed the input and output streams to be retained by
        // this client, otherwise the retainCount wasn't right. The end-
        // result being that when we tried to remove the streams from the
        // run loop then the loop would hang.
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        
        self.istream = (__bridge_transfer NSInputStream *)readStream;
        [istream setDelegate:self];
        [istream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        [istream open];
        
        self.ostream = (__bridge_transfer NSOutputStream *)writeStream;
        [ostream setDelegate:self];
        [ostream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        [ostream open];
    }
    
    if (readStream)
        CFRelease(readStream);
    
    if (writeStream)
        CFRelease(writeStream);
}

- (void)disconnect
{
    [self changeConnectingState:DISCONNECTING];
    
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    
    [self.ostream removeFromRunLoop:loop forMode:NSDefaultRunLoopMode];
    [self.ostream setDelegate:nil];
    [self.ostream close];
    self.ostream = nil;
    
    [self.istream removeFromRunLoop:loop forMode:NSDefaultRunLoopMode];
    [self.istream setDelegate:nil];
    [self.istream close];
    self.istream = nil;
    
    [self changeConnectingState:DISCONNECTED];
}

- (void)handlePacket:(ICBPacket *)packet
{
    packetsReceived++;
    
    if ([packet isKindOfClass:[ExitPacket class]])
    {
        [self disconnect];
    }
    else if ([packet isKindOfClass:[PingPacket class]])
    {
        PongPacket *packet = [[PongPacket alloc] init];
        [self sendPacket:packet];
    }
    else if ([packet isKindOfClass:[ProtocolPacket class]])
    {
        [self handleProtocolPacket:(ProtocolPacket *)packet];
    }
    else if ([packet isKindOfClass:[LoginPacket class]])
    {
        [self handleLoginPacket:(LoginPacket *)packet];
    }
    else if ([packet isKindOfClass:[PersonalPacket class]])
    {
        PersonalPacket *p = (PersonalPacket *)packet;
        [nicknameHistory add:p.nick];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kICBClient_packet
                                                        object:packet];
}

- (void)handleLoginPacket:(LoginPacket *)packet
{
    // TODO: reconnectNeeded = false

    // TODO: make echoback optional?
    CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"echoback"
                                                 optionalArgs:@"verbose"];
    [self sendPacket:p];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kICBClient_loginOK
                                                        object:self];
}

- (void)handleProtocolPacket:(ProtocolPacket *)packet
{
    // TODO: check protocol packet version
    LoginPacket *loginPacket = [[LoginPacket alloc] initWithUserDetails:nickname
                                                                   nick:nickname
                                                                  group:initialGroup
                                                                command:@"login"
                                                               password:password];
    [self sendPacket:loginPacket];
}

- (void)sendPacket:(ICBPacket *)packet
{
    NSData *data = [packet data];
    packetsSent++;
    
    [outputQueue insertObject:data atIndex:0];
    [self flushOutputQueue];
}

- (NSString *)removeControlCharacters:(NSString *)s
{
    const NSUInteger n = [s length];
    NSMutableString *t = [NSMutableString stringWithCapacity:n];
    char c;
    for (NSUInteger i = 0; i < n; i++)
    {
        c = [s characterAtIndex:i];
        if (isspace(c))
            [t appendFormat:@"%c", c];
        else if (!iscntrl(c))
            [t appendFormat:@"%c", c];
    }
    return t;
}

- (void)sendOpenMessage:(NSString *)msg
{
    NSString *current;
    NSString *remaining = [self removeControlCharacters:msg];
    do {
        if ([remaining length] > MAX_OPEN_MESSAGE_SIZE)
        {
            current = [remaining substringToIndex:MAX_OPEN_MESSAGE_SIZE];
            NSRange range = [current rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                     options:NSBackwardsSearch];
            if (range.location != NSNotFound)
            {
                current = [current substringWithRange:NSMakeRange(0, range.location + 1)];
            }
            remaining = [remaining substringFromIndex:[current length]];
        }
        else
        {
            current = remaining;
            remaining = @"";
        }
        
        OpenPacket *p = [[OpenPacket alloc] initWithText:current];
        [self sendPacket:p];
    } while ([remaining length] > 0);
}

- (void)sendPersonalMessage:(NSString *)nick withMsg:(NSString *)msg
{
    NSString *current;
    NSString *remaining = [self removeControlCharacters:msg];
    do {
        if ([remaining length] > MAX_PERSONAL_MESSAGE_SIZE)
        {
            current = [remaining substringToIndex:MAX_PERSONAL_MESSAGE_SIZE];
            NSRange range = [current rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                     options:NSBackwardsSearch];
            if (range.location != NSNotFound)
            {
                current = [current substringWithRange:NSMakeRange(0, range.location + 1)];
            }
            remaining = [remaining substringFromIndex:[current length]];
        }
        else
        {
            current = remaining;
            remaining = @"";
        }
        
        NSString *s = [NSString stringWithFormat:@"%@ %@", nick, current];
        CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"m" optionalArgs:s];
        [self sendPacket:p];
    } while ([remaining length] > 0);
    
    [nicknameHistory add:nick];
}

- (void)sendWriteMessage:(NSString *)nick withMsg:(NSString *)msg
{
    NSString *current;
    NSString *remaining = [self removeControlCharacters:msg];
    do {
        if ([remaining length] > MAX_WRITE_MESSAGE_SIZE)
        {
            current = [remaining substringToIndex:MAX_WRITE_MESSAGE_SIZE];
            NSRange range = [current rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                     options:NSBackwardsSearch];
            if (range.location != NSNotFound)
            {
                current = [current substringWithRange:NSMakeRange(0, range.location + 1)];
            }
            remaining = [remaining substringFromIndex:[current length]];
        }
        else
        {
            current = remaining;
            remaining = @"";
        }
        
        CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"write"
                                                     optionalArgs:[NSString stringWithFormat:@"%@ %@", nick, current]];
        [self sendPacket:p];
    } while ([remaining length] > 0);
}

- (void)flushOutputQueue
{
    if ([self.ostream hasSpaceAvailable])
    {
        while ([outputQueue count] > 0)
        {
            NSData *data = (NSData *)[outputQueue lastObject];
            [outputQueue removeLastObject];
            
            uint8_t l = [data length];
            NSInteger written = [self.ostream write:&l maxLength:sizeof(l)];
            NSAssert(written == sizeof(l), @"unable to write packet length");
            written = [self.ostream write:[data bytes] maxLength:l];
            NSAssert(written == l, @"unable to write packet data");
        }
    }
}

- (void)handleInputStream:(NSInputStream *)stream
{
    // NOTE: it appears from reviewing
    // http://www.opensource.apple.com/source/CFNetwork/CFNetwork-129.9/Stream/CFSocketStream.c
    // that the internal CFStream buffer sizes are 32 KB, so we don't need
    // additional buffering logic in this class.
    
    while ([stream hasBytesAvailable])
    {
        if (readState == kWaitingForPacket)
        {
            NSInteger len = [stream read:&packetLength
                               maxLength:sizeof(packetLength)];
            if (len < 0)
            {
            }
            else if (len == 0)
            {
            }
            else
            {
                bytesReceived += len;
                bufferPos = 0;
                readState = kReadingPacket;
            }
        }
        else if (readState == kReadingPacket)
        {
            uint8_t *buffer = [packetBuffer mutableBytes];
            NSInteger len = [stream read:&buffer[bufferPos]
                               maxLength:packetLength - bufferPos];
            if (len < 0)
            {
            }
            else if (len == 0)
            {
            }
            else
            {
                bytesReceived += len;
                bufferPos += len;
                if (bufferPos < packetLength)
                {
                    DLog(@"packet not fully read, need %u more bytes",
                         packetLength - bufferPos);
                }
                else
                {
                    NSData *packetData = [NSData dataWithBytes:buffer
                                                        length:packetLength];
                    ICBPacket *packet = [ICBPacket packetWithBuffer:packetData];
                    
                    [inputQueue insertObject:packet atIndex:0];
                    readState = kWaitingForPacket;
                }
            }
        }
    }
    
    while ([inputQueue count] > 0)
    {
        ICBPacket *packet = (ICBPacket *)[inputQueue lastObject];
        [inputQueue removeLastObject];
        [self handlePacket:packet];
    }
}

- (void)handleOutputStream:(NSOutputStream *)stream
{
    [self flushOutputQueue];
}

#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
                                
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            readState = kWaitingForPacket;
            [ns postNotificationName:kICBClient_connected object:self];
            break;
            
        case NSStreamEventHasBytesAvailable:
            [self handleInputStream:(NSInputStream *)theStream];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            [self handleOutputStream:(NSOutputStream *)theStream];
            break;
            
        case NSStreamEventErrorOccurred:
            DLog(@"socket error!");
            break;
            
        case NSStreamEventEndEncountered:
            DLog(@"socket closed!");
            [self disconnect];
            break;
            
        default:
            break;
    }
}

@end