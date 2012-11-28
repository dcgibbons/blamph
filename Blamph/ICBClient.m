//
//  ICBClient.m
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ICBClient.h"
#import "BeepPacket.h"
#import "CommandPacket.h"
#import "CommandOutputPacket.h"
#import "ErrorPacket.h"
#import "ExitPacket.h"
#import "LoginPacket.h"
#import "NoOpPacket.h"
#import "PersonalPacket.h"
#import "PingPacket.h"
#import "PongPacket.h"
#import "ProtocolPacket.h"
#import "OpenPacket.h"
#import "StatusPacket.h"

@interface ICBClient () <NSStreamDelegate>
{
@private
    enum { DISCONNECTED, DISCONNECTING, CONNECTING, CONNECTED } connectionState;
    
    NSString *nickname;
    NSString *initialGroup;
    NSString *password;
    
    uint8_t packetLength, bufferPos;
    
    NSMutableData *packetBuffer;
    NSMutableArray *inputQueue;
    NSMutableArray *outputQueue;
    
    enum { kWaitingForPacket, kReadingPacket } readState;
    
    // statistics
    NSUInteger bytesReceived;
    NSUInteger bytesSent;
    NSUInteger packetsReceived;
    NSUInteger packetsSent;
}

@property (nonatomic, retain) NSInputStream *istream;
@property (nonatomic, retain) NSOutputStream *ostream;
@property (nonatomic, retain) NSTimer *keepAliveTimer;

- (void)startKeepAliveTimer;
- (void)stopKeepAliveTimer;
- (void)fireKeepAliveTimer:(id)arg;

@end

@implementation ICBClient

@synthesize istream=_istream;
@synthesize ostream=_ostream;
@synthesize nicknameHistory=_nicknameHistory;

- (id)init
{
    if (self = [super init])
    {
        connectionState = DISCONNECTED;
        
        packetBuffer = [NSMutableData dataWithCapacity:MAX_PACKET_SIZE];
        inputQueue = [NSMutableArray arrayWithCapacity:100];
        outputQueue = [NSMutableArray arrayWithCapacity:100];
        self.nicknameHistory = [[NicknameHistory alloc] init];
        
        bytesReceived = 0;
        bytesSent = 0;
        packetsReceived = 0;
        packetsSent = 0;
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(clientNotify:)
//                                                     name:kICBClient_packet
//                                                   object:nil];
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
            [self stopKeepAliveTimer];
//            self.istream = nil;
//            self.ostream = nil;
            break;
        case DISCONNECTING:
            notificationName = kICBClient_disconnecting;
            break;
        case CONNECTING:
            notificationName = kICBClient_connecting;
            break;
        case CONNECTED:
            notificationName = kICBClient_connected;
            [self startKeepAliveTimer];
            break;
    }
    
    DLog(@"Sending %@ notification", notificationName);
    
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
        
        NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
        
        [inputStream setDelegate:self];
        [inputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        [inputStream open];
        
        NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        [outputStream setDelegate:self];
        [outputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        [outputStream open];
        
        self.istream = inputStream;
        self.ostream = outputStream;
    }
    else
    {
        if (readStream)
            CFRelease(readStream);
        if (writeStream)
            CFRelease(writeStream);
    }
}

- (void)disconnect
{
    [self changeConnectingState:DISCONNECTING];
    
    NSRunLoop *loop = [NSRunLoop currentRunLoop];

    [self.ostream close];
    [self.ostream removeFromRunLoop:loop forMode:NSDefaultRunLoopMode];
    [self.ostream setDelegate:nil];
    self.ostream = nil;

    [self.istream close];
    [self.istream removeFromRunLoop:loop forMode:NSDefaultRunLoopMode];
    [self.istream setDelegate:nil];
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
        [self.nicknameHistory add:p.nick];
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
    // convert the string to ASCII with a lossy conversion so that we can
    // remove any invalid characters from the input that ICB doesn't understand
    // because of it's ASCII limitation
    NSData *data = [s dataUsingEncoding:NSASCIIStringEncoding
                   allowLossyConversion:YES];
    s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
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
    
    [self.nicknameHistory add:nick];
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
    
    NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
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

- (void)startKeepAliveTimer
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults boolForKey:@"sendKeepAlives"])
    {
        NSTimeInterval interval = [userDefaults doubleForKey:@"keepAliveInterval"];
        DLog(@"Scheduleding keep-alive timer at %.2f", interval);
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                          target:self
                                                        selector:@selector(fireKeepAliveTimer:)
                                                        userInfo:nil
                                                         repeats:YES];
        self.keepAliveTimer = timer;
    }
}

- (void)stopKeepAliveTimer
{
    [self.keepAliveTimer invalidate];
    self.keepAliveTimer = nil;
}

- (void)fireKeepAliveTimer:(id)arg
{
    NoOpPacket *packet = [[NoOpPacket alloc] init];
    DLog(@"Sending %@ for network keep-alive", packet);
    [self sendPacket:packet];
}

#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    DLog(@"stream event=%lu", streamEvent);
    
    NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            readState = kWaitingForPacket;
            [self changeConnectingState:CONNECTED];
            break;
            
        case NSStreamEventHasBytesAvailable:
            [self handleInputStream:(NSInputStream *)theStream];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            [self handleOutputStream:(NSOutputStream *)theStream];
            break;
            
        case NSStreamEventErrorOccurred:
            DLog(@"socket error!");
            if (connectionState == CONNECTING)
            {
                [ns postNotificationName:kICBClient_connectfailed object:self];
            }
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