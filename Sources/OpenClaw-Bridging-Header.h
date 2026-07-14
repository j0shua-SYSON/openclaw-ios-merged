//
//  OpenClaw-Bridging-Header.h
//
//  Objective-C symbols exposed to OpenClaw's Swift.
//
//  Delta mode: we FORWARD-DECLARE DeltaLauncher here rather than
//  `#import <Delta/DeltaLauncher.h>`. Delta.framework is a mixed ObjC+Swift
//  framework, and importing its Clang module makes Swift eagerly load the
//  same-named Swift overlay (Delta.swiftmodule), which requires ~12 statically
//  linked transitive modules (Roxas, Harmony, SQLite, RevenueCat, …) that ship
//  no module interfaces → "missing required modules". A bare forward declaration
//  loads no module at all; the class is resolved from the embedded Delta.framework
//  at link time via the ObjC runtime. See Modes/Delta/fork/DeltaLauncher.h.
//

#import <UIKit/UIKit.h>

@interface DeltaLauncher : NSObject
+ (UIViewController * _Nonnull)makeRootViewController;
@end

// Feather mode — same pattern: forward-declared (not imported from <Feather/…>) so
// OpenClaw's Swift never loads Feather's Swift module + its static transitive
// dependencies (Vapor, SwiftNIO, Zsign, OpenSSL, …). Resolved from the embedded
// Feather.framework at link time. See Modes/Feather/fork/FeatherLauncher.h.
@interface FeatherLauncher : NSObject
+ (UIViewController * _Nonnull)makeRootViewController;
@end

// iSH mode — same forward-declared pattern. iSH is all ObjC/C (no Swift module), but
// the launcher is still exposed only via this bare declaration; the class is resolved
// from the embedded iSH.framework at link time. iSHLauncher boots the emulated Linux
// kernel before returning the terminal VC. See Modes/iSH/fork/iSHLauncher.h.
@interface iSHLauncher : NSObject
+ (UIViewController * _Nonnull)makeRootViewController;
@end
