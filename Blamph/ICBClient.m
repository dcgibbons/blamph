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

#import "NSString+StringUtils.h"
#import "Reachability.h"

#define kSendKeepAlives         @"sendKeepAlives"
#define kKeepAliveInterval      @"keepAliveInterval"

@interface ICBClient () <NSStreamDelegate>
{
@private
    NSDictionary *_packetHandlers;

    enum { kDisconnected, kDisconnecting, kConnecting, kConnected } _connectionState;
    Reachability *_reachability;
    
    NSUInteger _reconnectNeeded;
    
    NSString *_hostname;
    UInt32 _port;
    NSString *_nickname;
    NSString *_alternateNickname;
    NSString *_initialGroup;
    NSString *_password;
    
    uint8_t _packetLength, _bufferPos;
    
    NSMutableData *_packetBuffer;
    NSMutableArray *_inputQueue;
    NSMutableArray *_outputQueue;
    
    enum { kWaitingForPacket, kReadingPacket } _readState;

    NSTimer *_keepAliveTimer;
    
    // statistics
    NSUInteger _bytesReceived;
    NSUInteger _bytesSent;
    NSUInteger _packetsReceived;
    NSUInteger _packetsSent;
}

@property (nonatomic, retain) NSInputStream *istream;
@property (nonatomic, retain) NSOutputStream *ostream;

@end

@implementation ICBClient

@synthesize istream=_istream;
@synthesize ostream=_ostream;
@synthesize nicknameHistory=_nicknameHistory;

- (id)init
{
    if (self = [super init])
    {
        [self setupPacketHandlers];
        
        _connectionState = kDisconnected;
        
        _packetBuffer = [NSMutableData dataWithCapacity:MAX_PACKET_SIZE];
        _inputQueue = [NSMutableArray arrayWithCapacity:100];
        _outputQueue = [NSMutableArray arrayWithCapacity:100];
        _nicknameHistory = [[NicknameHistory alloc] init];
        
        _bytesReceived = 0;
        _bytesSent = 0;
        _packetsReceived = 0;
        _packetsSent = 0;
        
        // here we set up a NSNotification observer. The Reachability that caused the notification
        // is passed in the object parameter
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    Reachability *reachability = notification.object;
    if (!reachability.isReachable && self.isConnected)
    {
        [self disconnect];
    }
}


- (BOOL)isConnected
{
    return (_connectionState == kConnecting || _connectionState == kConnected);
}

- (void)changeConnectingState:(int)newState
{
    _connectionState = newState;

    NSString *notificationName = nil;
    switch (_connectionState)
    {
        case kDisconnected:
            notificationName = kICBClient_disconnected;
            [self stopKeepAliveTimer];
            
            if (_reconnectNeeded == 1)
            {
                [self connectUsingHostname:_hostname
                                   andPort:_port
                               andNickname:_nickname
                          withAlterateNick:_alternateNickname
                                 intoGroup:_initialGroup
                              withPassword:_password];
            }
            else
            {
                _reconnectNeeded = 0;
            }
            break;
        case kDisconnecting:
            notificationName = kICBClient_disconnecting;
            break;
        case kConnecting:
            notificationName = kICBClient_connecting;
            break;
        case kConnected:
            notificationName = kICBClient_connected;
            [self startKeepAliveTimer];
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
            withAlterateNick:(NSString *)alternateNick
                   intoGroup:(NSString *)userGroup
                withPassword:(NSString *)userPassword
{
    if ([self isConnected])
    {
        @throw [NSException exceptionWithName:@"illegal state exception"
                                       reason:@"already connected"
                                     userInfo:nil];
    }
    
    [self changeConnectingState:kConnecting];
    
    // allocate a reachability object
    _reachability = [Reachability reachabilityWithHostname:hostname];
    [_reachability startNotifier];
    
    _hostname = hostname;
    _port = port;
    _nickname = userNickname;
    _alternateNickname = alternateNick;
    _initialGroup = userGroup;
    _password = userPassword;

    NSHost *host = [NSHost hostWithName:_hostname];
    NSInputStream *inputStream = nil;
    NSOutputStream *outputStream = nil;
    [NSStream getStreamsToHost:host
                          port:port
                   inputStream:&inputStream
                  outputStream:&outputStream];

    if (inputStream && outputStream)
    {
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        
        [inputStream setDelegate:self];
        [inputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        [inputStream open];
        self.istream = inputStream;
        
        [outputStream setDelegate:self];
        [outputStream scheduleInRunLoop:loop forMode:NSDefaultRunLoopMode];
        [outputStream open];
        self.ostream = outputStream;
    }
}

- (void)disconnect
{
    if ([self isConnected])
    {
        [self changeConnectingState:kDisconnecting];
        
        [_reachability stopNotifier];
        
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        
        [self.ostream close];
        [self.ostream removeFromRunLoop:loop forMode:NSDefaultRunLoopMode];
        [self.ostream setDelegate:nil];
        self.ostream = nil;
        
        [self.istream close];
        [self.istream removeFromRunLoop:loop forMode:NSDefaultRunLoopMode];
        [self.istream setDelegate:nil];
        self.istream = nil;
        
        [self changeConnectingState:kDisconnected];
    }
}

- (void)setupPacketHandlers
{
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSValue valueWithPointer:@selector(handleErrorPacket:)], [ErrorPacket className],
                       [NSValue valueWithPointer:@selector(handleExitPacket:)], [ExitPacket className],
                       [NSValue valueWithPointer:@selector(handleLoginPacket:)], [LoginPacket className],
                       [NSValue valueWithPointer:@selector(handlePersonalPacket:)], [PersonalPacket className],
                       [NSValue valueWithPointer:@selector(handleProtocolPacket:)], [ProtocolPacket className],
                       nil];
    _packetHandlers = d;
}

- (void)handleErrorPacket:(ErrorPacket *)packet
{
    if ([[packet errorText] compare:@"Nickname already in use."] == NSOrderedSame)
    {
        _reconnectNeeded++;
    }
}

- (void)handleLoginPacket:(LoginPacket *)packet
{
    _reconnectNeeded = 0;
    
    // TODO: make echoback optional?
    CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"echoback"
                                                 optionalArgs:@"verbose"];
    [self sendPacket:p];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kICBClient_loginOK
                                                        object:self];
}

- (void)handleExitPacket:(ExitPacket *)packet
{
    [self disconnect];
}

- (void)handlePersonalPacket:(PersonalPacket *)packet
{
    // anytime a personal packet comes in, add it to the nickname history
    PersonalPacket *p = (PersonalPacket *)packet;
    [self.nicknameHistory add:p.nick];
}

- (void)handlePingPacket:(PingPacket *)packet
{
    PongPacket *pongPacket = [[PongPacket alloc] init];
    [self sendPacket:pongPacket];
}

- (void)handleProtocolPacket:(ProtocolPacket *)packet
{
    if (packet.protocolLevel != 1)
    {
        DLog(@"Unexpected protocol received: %@", packet);
        [self disconnect];
    }
    else
    {
        NSString *nick = _nickname;
        if (_reconnectNeeded > 0)
        {
            nick = _alternateNickname;
        }
        
        LoginPacket *loginPacket = [[LoginPacket alloc] initWithUserDetails:nick
                                                                       nick:nick
                                                                      group:_initialGroup
                                                                    command:@"login"
                                                                   password:_password];
        [self sendPacket:loginPacket];
    }
}

- (void)handlePacket:(ICBPacket *)packet
{
    _packetsReceived++;

    SEL selector = [[_packetHandlers valueForKey:[packet className]] pointerValue];
    if (selector)
    {
        SuppressPerformSelectorLeakWarning([self performSelector:selector
                                                      withObject:packet]);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kICBClient_packet
                                                        object:packet];
}

- (void)sendPacket:(ICBPacket *)packet
{
    NSData *data = [packet data];
    [_outputQueue insertObject:data atIndex:0];
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
    
    return [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)sendOpenMessage:(NSString *)msg
{
    NSString *s = [self removeControlCharacters:msg];
    if ([s length] > 0)
    {
        NSArray *splits = [s smartSplitByLength:MAX_OPEN_MESSAGE_SIZE];
        for (NSString *split in splits)
        {
            OpenPacket *p = [[OpenPacket alloc] initWithText:split];
            [self sendPacket:p];
        }
    }
}

- (void)sendPersonalMessage:(NSString *)nick withMsg:(NSString *)msg
{
    NSString *s = [self removeControlCharacters:msg];
    if ([s length] > 0)
    {
        
        NSArray *splits = [s smartSplitByLength:MAX_PERSONAL_MESSAGE_SIZE];
        for (NSString *split in splits)
        {
            NSString *s = [NSString stringWithFormat:@"%@ %@", nick, split];
            CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"m" optionalArgs:s];
            [self sendPacket:p];
        }
        
        [self.nicknameHistory add:nick];
    }
}

- (void)sendWriteMessage:(NSString *)nick withMsg:(NSString *)msg
{
    NSString *s = [self removeControlCharacters:msg];
    if ([s length] > 0)
    {
        NSArray *splits = [s smartSplitByLength:MAX_WRITE_MESSAGE_SIZE];
        for (NSString *split in splits)
        {
            NSString *s = [NSString stringWithFormat:@"%@ %@", nick, split];
            CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"write"
                                                         optionalArgs:s];
            [self sendPacket:p];
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
        if (_readState == kWaitingForPacket)
        {
            NSInteger len = [stream read:&_packetLength
                               maxLength:sizeof(_packetLength)];
            if (len < 0)
            {
                // TODO: handle error
            }
            else if (len == 0)
            {
                // end-of-stream
            }
            else
            {
                _bytesReceived += len;
                _bufferPos = 0;
                _readState = kReadingPacket;
            }
        }
        else if (_readState == kReadingPacket)
        {
            uint8_t *buffer = [_packetBuffer mutableBytes];
            NSInteger len = [stream read:&buffer[_bufferPos]
                               maxLength:_packetLength - _bufferPos];
            if (len < 0)
            {
                // TODO: handle error
            }
            else if (len == 0)
            {
                // end-of-stream
            }
            else
            {
                _bytesReceived += len;
                _bufferPos += len;
                if (_bufferPos < _packetLength)
                {
                    DLog(@"packet not fully read, need %u more bytes",
                         _packetLength - _bufferPos);
                }
                else
                {
                    NSData *packetData = [NSData dataWithBytes:buffer
                                                        length:_packetLength];
                    ICBPacket *packet = [ICBPacket packetWithBuffer:packetData];
                    
                    [_inputQueue insertObject:packet atIndex:0];
                    _readState = kWaitingForPacket;
                }
            }
        }
    }
    
    // handle any packets that were fully received
    while ([_inputQueue count] > 0)
    {
        ICBPacket *packet = (ICBPacket *)[_inputQueue lastObject];
        [_inputQueue removeLastObject];
        [self handlePacket:packet];
    }
}

- (void)handleOutputStream:(NSOutputStream *)stream
{
    [self flushOutputQueue];
}

- (void)flushOutputQueue
{
    if ([self.ostream hasSpaceAvailable])
    {
        while ([_outputQueue count] > 0)
        {
            NSData *data = (NSData *)[_outputQueue lastObject];
            [_outputQueue removeLastObject];
            uint8_t l = [data length];
            
            NSInteger written = [self.ostream write:&l maxLength:sizeof(l)];
            NSAssert(written == sizeof(l), @"unable to write packet length");
            _bytesSent += written;
            
            written = [self.ostream write:[data bytes] maxLength:l];
            NSAssert(written == l, @"unable to write packet data");
            _bytesSent += written;

            _packetsSent++;
        }
    }
}

#pragma mark -
#pragma Keep Alive Timer methods

- (void)startKeepAliveTimer
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults boolForKey:kSendKeepAlives])
    {
        NSTimeInterval interval = [userDefaults doubleForKey:kKeepAliveInterval];
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                          target:self
                                                        selector:@selector(keepAlive:)
                                                        userInfo:nil
                                                         repeats:YES];
        _keepAliveTimer = timer;
    }
}

- (void)stopKeepAliveTimer
{
    [_keepAliveTimer invalidate];
    _keepAliveTimer = nil;
}

- (void)keepAlive:(id)arg
{
    NoOpPacket *packet = [[NoOpPacket alloc] init];
    [self sendPacket:packet];
}

#pragma mark -
#pragma mark NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            _readState = kWaitingForPacket;
            [self changeConnectingState:kConnected];
            break;
            
        case NSStreamEventHasBytesAvailable:
            [self handleInputStream:(NSInputStream *)theStream];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            [self handleOutputStream:(NSOutputStream *)theStream];
            break;
            
        case NSStreamEventErrorOccurred:
            if (_connectionState == kConnecting)
            {
                [ns postNotificationName:kICBClient_connectfailed object:self];
            }
            break;
            
        case NSStreamEventEndEncountered:
            [self disconnect];
            break;
            
        default:
            break;
    }
}

@end