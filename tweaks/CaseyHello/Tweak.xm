#import <Foundation/Foundation.h>

// Minimal proof-of-load. No UIKit changes, hooks, network calls, or persistence.
// The filter restricts injection to the Settings app.
%ctor {
    @autoreleasepool {
        NSLog(@"[CaseyHello] Loaded in %@",
              [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown");
    }
}
