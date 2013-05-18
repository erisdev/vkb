#include <Cocoa/Cocoa.h>

static NSString *const kVKBServiceName = @"Virtual Keyboard";

static CGEventFlags const kVKBForwardableFlagsMask = kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand;

static CGEventMask const kVKBForwardableEventsMask = 
    (1 << kCGEventFlagsChanged) |
    (1 << kCGEventKeyDown) |
    (1 << kCGEventKeyUp) |
    (1 << kCGEventLeftMouseDown) |
    (1 << kCGEventLeftMouseDragged) |
    (1 << kCGEventLeftMouseUp) |
    (1 << kCGEventMouseMoved) |
    (1 << kCGEventOtherMouseDown) |
    (1 << kCGEventOtherMouseDragged) |
    (1 << kCGEventOtherMouseUp) |
    (1 << kCGEventRightMouseDown) |
    (1 << kCGEventRightMouseDragged) |
    (1 << kCGEventRightMouseUp) |
    (1 << kCGEventScrollWheel);

@protocol VirtualKeyboard <NSObject>
@property(readonly, assign) CGSize displaySize;

- (void)pressKey:(CGKeyCode)key;
- (void)releaseKey:(CGKeyCode)key;
- (void)typeKey:(CGKeyCode)key;
// - (void)typeString:(NSString*)str;

- (void)postFlagsChangedEvent:(CGEventFlags)flags;
- (void)postKeyEvent:(CGKeyCode)key pressed:(BOOL)pressed;

- (void)postSerializedEvent:(NSData*)eventData;
@end

@protocol VKBServer <NSObject>
- (id<VirtualKeyboard>)virtualKeyboard;
@end
