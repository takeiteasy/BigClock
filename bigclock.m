/* bigclock (Mac only)
 Description: Semi-transparent clock that sits in the bottom right of the screen
              Becomes more opaque on mouse-over. Doesn't interfere with anything
              underneath. Also adds a little menubar icon to close the window.
 Build: clang bigclock.m -framework Cocoa -o bigclock
 
 The MIT License (MIT)

 Copyright (c) 2022 George Watson

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software,
 and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <Cocoa/Cocoa.h>

typedef enum {
    fadein,
    fadeout,
    nothing
} fade_state;
static fade_state state = nothing;

#define MAX_OPACITY_OFF .75
#define MIN_OPACITY_OFF .30
static double opacity_off = MIN_OPACITY_OFF;

@interface AppView : NSView {}
@end

@implementation AppView
- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self addTrackingRect:[self visibleRect]
                        owner:self
                     userData:nil
                 assumeInside:NO];
    }
    return self;
}

- (void)drawRect:(NSRect)frame {
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:frame
                                                         xRadius:6.
                                                         yRadius:6.];
    [[NSColor colorWithRed:0
                     green:0
                      blue:0
                     alpha:opacity_off] set];
    [path fill];
}

- (void)mouseEntered:(NSEvent*)event {
    state = fadein;
}

- (void)mouseExited:(NSEvent*)event {
    state = fadeout;
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate> {
    NSWindow* window;
    AppView* view;
    NSTextField* label;
    NSTimer* timer;
    NSTimer* fade_timer;
}
@property (strong, nonatomic) NSStatusItem* statusItem;
@end

@implementation AppDelegate : NSObject
- (id)init {
    if (self = [super init]) {
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(onExit:)
                   name:NSApplicationWillTerminateNotification
                 object:nil];
        
        _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        _statusItem.button.image = [NSImage imageWithSystemSymbolName:@"clock"
                                             accessibilityDescription:nil];
#if __MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
        _statusItem.highlightMode = YES;
#endif
        NSMenu *menu = [[NSMenu alloc] init];
        [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
        _statusItem.menu = menu;
        
        window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 310, 95)
                                             styleMask:NSWindowStyleMaskBorderless
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 310, 92)];
        view = [[AppView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
        timer = [NSTimer scheduledTimerWithTimeInterval:1.
                                                 target:self
                                               selector:@selector(update)
                                               userInfo:nil
                                                repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer
                                     forMode:NSModalPanelRunLoopMode];
        fade_timer = [NSTimer scheduledTimerWithTimeInterval:(1. / 60.)
                                                      target:self
                                                    selector:@selector(fade_update)
                                                    userInfo:nil
                                                     repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:fade_timer
                                     forMode:NSModalPanelRunLoopMode];
    }
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
    [window setTitle:NSProcessInfo.processInfo.processName];
    [window setFrameOrigin:NSMakePoint([[NSScreen mainScreen] visibleFrame].origin.x + [[NSScreen mainScreen] visibleFrame].size.width - [window frame].size.width - 20, 20)];
    [window setOpaque:NO];
    [window setExcludedFromWindowsMenu:NO];
    [window setBackgroundColor:[NSColor clearColor]];
    [window setIgnoresMouseEvents:YES];
    [window makeKeyAndOrderFront:self];
    [window setLevel:NSFloatingWindowLevel];
    [window setCanHide:NO];
    [window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    
    [label setStringValue:@""];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAlignment:NSTextAlignmentCenter];
    [label setFont:[NSFont systemFontOfSize:72.]];
    [label setTextColor:[[NSColor whiteColor] colorWithAlphaComponent:.5]];
    [[label cell] setBackgroundStyle:NSBackgroundStyleRaised];
    
    [window setContentView:view];
    [view addSubview:label];
    
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    [self update];
}

- (void)update {
    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"hh:mm:ss"];
    [label setStringValue:[fmt stringFromDate:[NSDate date]]];
    [view setNeedsDisplay:YES];
}

- (void)update_fade:(NSTimeInterval)v {
    opacity_off += (v / 10.);
    [label setTextColor:[[NSColor whiteColor] colorWithAlphaComponent:.25 + opacity_off]];
    [view setNeedsDisplay:YES];
}

- (void)fade_update {
    switch (state) {
        case fadein:
            if (opacity_off < MAX_OPACITY_OFF)
                [self update_fade:[[timer fireDate] timeIntervalSinceDate:[NSDate date]]];
            else {
                opacity_off = MAX_OPACITY_OFF;
                state = nothing;
            }
            break;
        case fadeout:
            if (opacity_off > MIN_OPACITY_OFF)
                [self update_fade:-([[timer fireDate] timeIntervalSinceDate:[NSDate date]])];
            else {
                opacity_off = MIN_OPACITY_OFF;
                state = nothing;
            }
            break;
        case nothing:
        default:
            break;
    }
}
@end

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp setDelegate:[AppDelegate new]];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
    return 0;
}
