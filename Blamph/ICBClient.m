//
//  ICBClient.m
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ICBClient.h"

#import <DebugKitFramework/DebugKit.h>
#import <ICBProtocolFramework/ICBProtocol.h>

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
    
    enum { kReady, kParseWhoListing } _clientState;
//    NSString *_currentGroupName;
//    NSMutableArray *_currentGroupUsers;
    
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

- (id)init
{
    if (self = [super init])
    {
        [self setupPacketHandlers];
        
        _connectionState = kDisconnected;
        _clientState = kReady;
        _currentGroupName = nil;
        _currentGroupUsers = [NSMutableArray arrayWithCapacity:100];
        
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
    DLog(@"Reachabilty Change");
    DLog(@"\t isConnectionOnDemand:%u", reachability.isConnectionOnDemand);
    DLog(@"\t isConnectionRequired:%u", reachability.isConnectionRequired);
    DLog(@"\t isInterventionRequired:%u", reachability.isInterventionRequired);
    DLog(@"\t isProxy:%u", reachability.isProxy);
    DLog(@"\t isReachable:%u", reachability.isReachable);
    DLog(@"\t isReachableViaWiFi:%u", reachability.isReachableViaWiFi);
    DLog(@"\t isReachableViaWWAN:%u", reachability.isReachableViaWWAN);
    if (!reachability.isReachable && self.isConnected)
    {
//        [self disconnect];
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
    BOOL wasConnecting = _connectionState == kConnecting;
    
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
    
    if (wasConnecting)
    {
        NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
        [ns postNotificationName:kICBClient_connectfailed object:self];
    }
}

- (void)setupPacketHandlers
{
    NSDictionary *d = @{[ErrorPacket className]: [NSValue valueWithPointer:@selector(handleErrorPacket:)],
                       [ExitPacket className]: [NSValue valueWithPointer:@selector(handleExitPacket:)],
                       [LoginPacket className]: [NSValue valueWithPointer:@selector(handleLoginPacket:)],
                       [PersonalPacket className]: [NSValue valueWithPointer:@selector(handlePersonalPacket:)],
                       [PingPacket className]: [NSValue valueWithPointer:@selector(handlePingPacket:)],
                       [ProtocolPacket className]: [NSValue valueWithPointer:@selector(handleProtocolPacket:)],
                       [StatusPacket className]: [NSValue valueWithPointer:@selector(handleStatusPacket:)],
                       [CommandOutputPacket className]: [NSValue valueWithPointer:@selector(handleCommandOutputPacket:)]};
    _packetHandlers = d;
}

- (BOOL)handleErrorPacket:(ErrorPacket *)packet
{
    BOOL broadcast = YES;
    
    if (_clientState == kParseWhoListing && [[packet errorText] hasPrefix:@"Server doesn't handle ICB_M_PING packets"])
    {
        DLog(@"received response to ping during who listing!");
        broadcast = NO;
        _clientState = kReady;
        [self didChangeValueForKey:@"currentGroupUsers"];
    }
    if ([[packet errorText] compare:@"Nickname already in use."] == NSOrderedSame)
    {
        _reconnectNeeded++;
    }
    
    return broadcast;
}

- (BOOL)handleLoginPacket:(LoginPacket *)packet
{
    _reconnectNeeded = 0;
    
    // TODO: make echoback optional?
    CommandPacket *p = [[CommandPacket alloc] initWithCommand:@"echoback"
                                                 optionalArgs:@"verbose"];
    [self sendPacket:p];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kICBClient_loginOK
                                                        object:self];
    
    return YES;
}

- (BOOL)handleExitPacket:(ExitPacket *)packet
{
    [self disconnect];
    return YES;
}

- (BOOL)handlePersonalPacket:(PersonalPacket *)packet
{
    // anytime a personal packet comes in, add it to the nickname history
    PersonalPacket *p = (PersonalPacket *)packet;
    [self.nicknameHistory add:p.nick];
    
    return YES;
}

- (BOOL)handlePingPacket:(PingPacket *)packet
{
    BOOL broadcast = YES;
    
    if (_clientState == kParseWhoListing)
    {
        DLog(@"PingPacket received while parsing who listing - all done!");
        broadcast = NO;
        _clientState = kReady;
    }
    else
    {
        PongPacket *pongPacket = [[PongPacket alloc] init];
        [self sendPacket:pongPacket];
    }
    
    return broadcast;
}

- (BOOL)handleProtocolPacket:(ProtocolPacket *)packet
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
    
    return YES;
}

- (BOOL)handleStatusPacket:(StatusPacket *)p
{
    NSString *header = p.header;
    NSString *text = p.text;
    NSError *error = NULL;
    NSRegularExpression *regex = nil;
    DLog(@"header=%@", header);
    
    if ([header compare:@"Status" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
        [header compare:@"Change" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        NSString *pattern = @"(?:You are now in group|renamed group to) (\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        
        NSArray *matches = [regex matchesInString:text
                                          options:0
                                            range:NSMakeRange(0, [text length])];
        DLog(@"matches=%@", matches);
        if ([matches count] > 0)
        {
            NSTextCheckingResult *match = matches[0];
            NSRange groupRange = [match rangeAtIndex:1];
            NSString *groupName = [text substringWithRange:groupRange];
            DLog(@"now in group %@", groupName);
            
            [self willChangeValueForKey:@"currentGroupName"];
            _currentGroupName = groupName;
            [self didChangeValueForKey:@"currentGroupName"];
            
            _clientState = kParseWhoListing;
            [self willChangeValueForKey:@"currentGroupUsers"];
            [_currentGroupUsers removeAllObjects];
            
            [self sendPacket:[[CommandPacket alloc] initWithCommand:@"w"
                                                       optionalArgs:@"."]];
            [self sendPacket:[[PingPacket alloc] init]];
        }
    }
    else if ([header compare:@"Arrive" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
             [header compare:@"Sign-on" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        NSString *pattern = @"(\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        
        NSArray *matches = [regex matchesInString:text
                                          options:0
                                            range:NSMakeRange(0, [text length])];
        if ([matches count] > 0)
        {
            NSTextCheckingResult *match = matches[0];
            NSRange range = [match rangeAtIndex:0];
            NSString *nick = [text substringWithRange:range];
            DLog(@"User %@ has just arrived in group %@", nick, _currentGroupName);

            [self willChangeValueForKey:@"currentGroupUsers"];
            [_currentGroupUsers addObject:nick];
            [self didChangeValueForKey:@"currentGroupUsers"];
            
            DLog(@"_currentGroupUsers %@", _currentGroupUsers);
        }
    }
    else if ([header compare:@"Depart" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
             [header compare:@"Sign-off" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        NSString *pattern = @"(\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        
        NSArray *matches = [regex matchesInString:text
                                          options:0
                                            range:NSMakeRange(0, [text length])];
        if ([matches count] > 0)
        {
            NSTextCheckingResult *match = matches[0];
            NSRange range = [match rangeAtIndex:0];
            NSString *nick = [text substringWithRange:range];
            DLog(@"User %@ has just left group %@", nick, _currentGroupName);
            [self willChangeValueForKey:@"currentGroupUsers"];
            [_currentGroupUsers removeObject:nick];
            [self didChangeValueForKey:@"currentGroupUsers"];
            DLog(@"_currentGroupUsers %@", _currentGroupUsers);
        }
    }
    
    return YES;
}

- (BOOL)handleCommandOutputPacket:(CommandOutputPacket *)p
{
    BOOL broadcast = YES;
    
    if (_clientState == kParseWhoListing)
    {
        DLog(@"commandOutputPacket while in wholisting: %@", [[p data] hexDump]);
        broadcast = NO;
        if ([p.outputType compare:@"wl"] == NSOrderedSame)
        {
            NSString *nickname = [p nickname];
            [_currentGroupUsers addObject:nickname];
        }
    }
    
    return broadcast;
}

- (void)handlePacket:(ICBPacket *)packet
{
    _packetsReceived++;
    
    DLog(@"handlePacket: %@", packet);

    BOOL broadcast = YES;
    SEL selector = [[_packetHandlers valueForKey:[packet className]] pointerValue];
    if (selector)
    {
//        broadcast = SuppressPerformSelectorLeakWarning([self performSelector:selector
//                                                                  withObject:packet]);
        broadcast = [self performSelector:selector withObject:packet];
    }

    if (broadcast)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kICBClient_packet
                                                            object:packet];
    }
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
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            _readState = kWaitingForPacket;
            _clientState = kReady;
            _currentGroupName = nil;
            [_currentGroupUsers removeAllObjects];
            [self changeConnectingState:kConnected];
            break;
            
        case NSStreamEventHasBytesAvailable:
            [self handleInputStream:(NSInputStream *)theStream];
            break;
            
        case NSStreamEventHasSpaceAvailable:
            [self handleOutputStream:(NSOutputStream *)theStream];
            break;
            
        case NSStreamEventErrorOccurred:
            [self disconnect];
            break;
            
        case NSStreamEventEndEncountered:
            [self disconnect];
            break;
            
        default:
            break;
    }
}

@end