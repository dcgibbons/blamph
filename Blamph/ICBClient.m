//
//  ICBClient.m
//  Blamph
//
//  Created by Chad Gibbons on 7/5/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "ICBClient.h"


@implementation ICBClient

- (id)init
{
    if (self = [super init])
    {
        inputBuffer = [NSMutableData dataWithCapacity:8 * 1024];
        outputBuffer = [NSMutableData dataWithCapacity:8 * 1024];
        
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

- (void)handlePacket:(NSNotification *)notification
{
    ICBPacket *packet = [notification object];
    DLog("handlePacket: packet received! %@", packet);

    if ([packet isKindOfClass:[ExitPacket class]])
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

- (void)handleErrorPacket:(ErrorPacket *)packet
{
    DLog(@"ICBClient: [=Error=] %@", [packet errorText]);
}

- (void)handleLoginPacket:(LoginPacket *)packet
{
    DLog(@"ICBClient: Login OK");
    // TODO: reconnectNeeded = false
}

- (void)handleProtocolPacket:(ProtocolPacket *)packet
{
    NSString *id = @"testuser";
    NSString *nick = @"tester";
    NSString *group = @"";
    NSString *command = @"login";
    NSString *passwd = @"";

    LoginPacket *loginPacket = [[LoginPacket alloc] initWithUserDetails:id nick:nick group:group command:command password:passwd];
    [self sendPacket:loginPacket];
    
    /* set the appropriate echoback state */
//    int echoback = clientProperties.getEchoback();
//    switch (echoback) {
//        case Echoback.ECHOBACK_ON:
//            sendCommandMessage("echoback", "on");
//            break;
//        case Echoback.ECHOBACK_VERBOSE_SERVER:
//            sendCommandMessage("echoback", "verbose");
//            break;
//        default:
//            break;
//    }
//    
//    executeInitScript();    
}

- (void)sendPacket:(ICBPacket *)packet
{
    NSData *data = [packet data];
    DLog(@"Sending Packet!!!\n%@", [data hexDump]);
    
    NSUInteger dataLength = [data length];
    NSAssert(dataLength <= 255, @"packet is too large");
    uint8_t l = dataLength;
    
    [outputBuffer appendBytes:&l length:sizeof(l)];
    [outputBuffer appendBytes:[data bytes] length:dataLength];
    
    [self flushOutputBuffer];
}

- (void)flushOutputBuffer
{
    NSUInteger bufferLength = [outputBuffer length];
    if (bufferLength > 0 && [ostream hasSpaceAvailable])
    {
        NSInteger written = [ostream write:[outputBuffer bytes] maxLength:bufferLength];
        DLog(@"ICBPacket: flushOutputBuffer wrote %d bytes", written);
        
        if (written < 0)
        {
            DLog(@"Oh, No! NSOutputStream write failure. Will our event handler receive the error, too?");
        } 
        else if (written > 0)
        {
            if (written == bufferLength)
            {
                [outputBuffer setLength:0];
            } 
            else 
            {
                NSRange replacementRange = NSMakeRange(0, written);
                NSUInteger remainingLength = bufferLength - written;
                DLog(@"replacing output buffer range(%u,%u) with buffer of length %u where original length was %u",
                     replacementRange.location, replacementRange.length, remainingLength, bufferLength);
                [outputBuffer replaceBytesInRange:replacementRange 
                                        withBytes:&[outputBuffer bytes][written]
                                           length:remainingLength];
            }
        }
    }
}

#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    NSUInteger len = 0;
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            DLog(@"NSStreamEventOpenCompleted");
            readState = kWaitingForPacket;
            break;
            
        case NSStreamEventHasBytesAvailable:
        {
            DLog(@"NSStreamEventHasBytesAvailable");
            
            NSInputStream *inputStream = (NSInputStream *)theStream;
            
            while ([inputStream hasBytesAvailable]) 
            {
                switch (readState) {
                    case kWaitingForPacket:
                        len = [inputStream read:&packetLength maxLength:sizeof(packetLength)];
                        DLog("State: new packet detected, packetLength=%u len=%u", packetLength, len);
                        bytesRead = 0;
                        readState = kReadingPacket;
                        break;
                    case kReadingPacket:
                    {
                        uint8_t buffer[256];
                        len = [inputStream read:buffer maxLength:sizeof(buffer)];
                        bytesRead += len;
                        DLog("State: reading packet, packetLength=%u bytesRead=%u len=%u", packetLength, bytesRead, len);
                        [inputBuffer appendBytes:buffer length:len];
                        break;
                    }
                }
                
                if (bytesRead >= packetLength) {
                    DLog("full packet received! buffer=\n%@", [inputBuffer hexDump]);
                    ICBPacket *packet = [ICBPacket packetWithBuffer:inputBuffer];
                    DLog("Packet: %@", packet);
                    
                    readState = kWaitingForPacket;
                    [inputBuffer setLength:0]; // TODO: is this right?
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ICBPacket" object:packet];
                }
            }
            
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:
            DLog(@"NSStreamEventHasSpaceAvailable");
            [self flushOutputBuffer];
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
