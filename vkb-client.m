#include "vkb.h"
#include <CoreFoundation/CoreFoundation.h>

static inline CGSize _divCGSize(CGSize a, CGSize b)
{
    return CGSizeMake(a.width / b.width, a.height / b.height);
}

@interface VKBClient : NSObject {
    id<VirtualKeyboard> kb;
    CGEventFlags oldFlags;
    BOOL forwardEvents;
}
@property(readwrite, assign) BOOL shouldForwardEvents;

+ (int)run:(int)argc :(char**)argv;
- (id)initWithProxy:(id<VirtualKeyboard>)proxy;
- (void)attachToRunLoop;

- (BOOL)handleEvent:(CGEventRef)event;
- (BOOL)forwardEvent:(CGEventRef)event;

@end

static CGEventRef _vkbEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userData);

@implementation VKBClient

+ (int)run:(int)argc :(char**)argv
{
    if (argc >= 2) {
        NSString *hostName = [NSString stringWithUTF8String:argv[1]];
        
        id<NSObject> serverProxy = [NSConnection rootProxyForConnectionWithRegisteredName:kVKBServiceName host:hostName usingNameServer:[NSSocketPortNameServer sharedInstance]];
        
        if ([serverProxy conformsToProtocol:@protocol(VKBServer)]) {
            id<VKBServer> server = (id<VKBServer>)serverProxy;
            VKBClient *client = [[[self alloc] initWithProxy:[server virtualKeyboard]] autorelease];
            
            [client attachToRunLoop];
            [[NSRunLoop currentRunLoop] run];
            return 0;
        }
        else {
            NSLog(@"failed connection to %@", hostName);
            return -1;
        }
    }
    else {
        NSLog(@"missing required hostname argument");
        return -1;
    }
}

- (id)initWithProxy:(id<VirtualKeyboard>)proxy
{
    if (self = [super init]) {
        self.shouldForwardEvents = NO;
        kb = [proxy retain];
    }
    return self;
}

- (void)dealloc
{
    [kb release];
    [super dealloc];
}

- (void)attachToRunLoop
{
    NSLog(@"creating event tap...");
    
    CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, kVKBForwardableEventsMask, _vkbEventCallback, self);
    
    if (!eventTap) {
        NSLog(@"failed to create event tap");
        exit(-1);
    }
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(NULL, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    CGEventTapEnable(eventTap, true);
    
    NSLog(@"event tap registered");
}

- (BOOL)shouldForwardEvents
{
    return forwardEvents;
}

- (void)setShouldForwardEvents:(BOOL)flag
{
    ProcessSerialNumber psn = {0, kCurrentProcess};
    
    if (flag) {
        NSLog(@"input forwarding enabled");
        forwardEvents = YES;
    }
    else {
        NSLog(@"input forwarding disabled");
        forwardEvents = NO;
    }
}

- (BOOL)handleEvent:(CGEventRef)event
{
    CGEventType eventType = CGEventGetType(event);
    CGEventFlags flags = CGEventGetFlags(event);
    if (eventType == kCGEventKeyDown && (flags & kCGEventFlagMaskSecondaryFn)) {
        CGKeyCode key = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        switch (key) {
            case 0x35: { /* ESC */
                self.shouldForwardEvents = !forwardEvents;
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)forwardEvent:(CGEventRef)event
{
    if (forwardEvents) {
        CGEventType eventType = CGEventGetType(event);
        BOOL forward = NO;
        
        if (eventType == kCGEventFlagsChanged) {
            // sanitize flags
            CGEventFlags newFlags = CGEventGetFlags(event) * kVKBForwardableFlagsMask;
            if (newFlags ^ oldFlags) {
                // only forward event if forwardable flags have changed
                CGEventSetFlags(event, oldFlags = newFlags);
                forward = YES;
            }
        }
        else if ((1 << eventType) & kVKBForwardableEventsMask) {
            forward = YES;
        }
        
        if (forward) {
            CFDataRef eventData = CGEventCreateData(NULL, event);
            [kb postSerializedEvent:(NSData*)eventData];
            CFRelease(eventData);
            
            return YES;
        }
    }
    return NO;
}

@end

static CGEventRef _vkbEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userData)
{
    VKBClient *client = (VKBClient*)userData;
    return ([client handleEvent:event] || [client forwardEvent:event]) ? NULL : event;
}

int main(int argc, char **argv)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int status = [VKBClient run:argc :argv];
    [pool drain];
    return status;
}
