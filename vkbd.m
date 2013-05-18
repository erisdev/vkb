#include "vkb.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>

@interface VirtualKeyboard : NSObject <VirtualKeyboard>
@end

@interface VKBServer : NSObject <VKBServer>
@end

@interface VKBDelegate : NSObject <NSConnectionDelegate>
@end

@implementation VirtualKeyboard

- (CGSize)displaySize
{
    return CGDisplayBounds(kCGDirectMainDisplay).size;
}

- (void)pressKey:(CGKeyCode)key
{
    [self postKeyEvent:key pressed:TRUE];
}

- (void)releaseKey:(CGKeyCode)key
{
    [self postKeyEvent:key pressed:FALSE];
}

- (void)typeKey:(CGKeyCode)key
{
    [self postKeyEvent:key pressed:TRUE];
    [self postKeyEvent:key pressed:FALSE];
}

// - (void)typeString:(NSString*)str
// {
//     // TODO -[VirtualKeyboard typeString:]
// }

- (void)postFlagsChangedEvent:(CGEventFlags)flags
{
    CGEventRef event = CGEventCreate(NULL);
    CGEventSetType(event, kCGEventFlagsChanged);
    CGEventSetFlags(event, flags & kVKBForwardableFlagsMask);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

- (void)postKeyEvent:(CGKeyCode)key pressed:(BOOL)pressed
{
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)key, pressed);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

- (void)postSerializedEvent:(NSData*)eventData
{
    CGEventRef event = CGEventCreateFromData(NULL, (CFDataRef)eventData);
    if (event) {
        switch (CGEventGetType(event)) {
            case kCGEventFlagsChanged: {
                // sanitize flags
                CGEventSetFlags(event, CGEventGetFlags(event) & kVKBForwardableFlagsMask);
                CGEventPost(kCGHIDEventTap, event);
                break;
            }
            case kCGEventKeyDown:
            case kCGEventKeyUp:
            case kCGEventLeftMouseDown:
            case kCGEventLeftMouseDragged:
            case kCGEventLeftMouseUp:
            case kCGEventMouseMoved:
            case kCGEventOtherMouseDown:
            case kCGEventOtherMouseDragged:
            case kCGEventOtherMouseUp:
            case kCGEventRightMouseDown:
            case kCGEventRightMouseDragged:
            case kCGEventRightMouseUp:
            case kCGEventScrollWheel:
            {
                // pass these events as-is
                CGEventPost(kCGHIDEventTap, event);
                break;
            }
        }
        CFRelease(event);
    }
    else {
        NSLog(@"invalid event data received: %@", eventData);
    }
}

@end

@implementation VKBServer

- (id<VirtualKeyboard>)virtualKeyboard
{
    return [[VirtualKeyboard new] autorelease];
}

@end

@implementation VKBDelegate

- (BOOL)connection:(NSConnection*)parent shouldMakeNewConnection:(NSConnection*)child
{
    if ([child.receivePort isKindOfClass:[NSSocketPort class]]) {
        NSSocketPort *port = (NSSocketPort*)child.sendPort;
        
        // fetch address and convert it to a human readable form
        struct sockaddr addr;
        char hostname[NI_MAXHOST];
        
        [port.address getBytes:&addr length:sizeof(addr)];
        
        if (0 != getnameinfo(&addr, sizeof(addr), hostname, sizeof(hostname), NULL, 0, 0)) {
            // can't idenfity the host? let's not.
            return NO;
        }
        
        NSAlert *alert = [NSAlert alertWithMessageText:@"Connection Request" defaultButton:@"Decline" alternateButton:@"Accept" otherButton:nil informativeTextWithFormat:@"The user at %s is requesting control.", hostname];
        alert.alertStyle = NSInformationalAlertStyle;
        
        [NSApp activateIgnoringOtherApps:NO];
        return [alert runModal] == NSAlertAlternateReturn;
    }
    else {
        return NO;
    }
}

// - (NSData*)authenticationDataForComponents:(NSArray*)components
// {
//     
// }
// 
// - (BOOL)authenticateComponents:(NSArray*)components withData:(NSData*)signature
// {
//     
// }

@end

int main(int argc, char **argv)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    NSPort *port = [NSSocketPort port];
    NSConnection *connection = [NSConnection connectionWithReceivePort:port sendPort:port];
    
    connection.rootObject = [[VKBServer new] autorelease];
    connection.delegate = [[VKBDelegate new] autorelease];
    
    if (![connection registerName:kVKBServiceName withNameServer:[NSSocketPortNameServer sharedInstance]]) {
        NSLog(@"unable to register as %@", kVKBServiceName);
        return -1;
    }
    
    ProcessSerialNumber me = {0, kCurrentProcess};
    TransformProcessType(&me, kProcessTransformToUIElementApplication);
    
    [[NSRunLoop mainRunLoop] run];
    
    [pool drain];
    return 0;
}