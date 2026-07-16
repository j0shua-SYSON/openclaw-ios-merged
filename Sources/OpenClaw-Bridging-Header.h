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

// UTM SE mode — same forward-declared pattern. UTMLauncher is an @objc(UTMLauncher) Swift
// class inside UTM.framework; forward-declaring it (not `import UTM`) keeps OpenClaw's Swift
// from loading UTM's large transitive module graph (QEMUKit, CocoaSpice, the SwiftUI VM
// machinery). The class is resolved from the embedded UTM.framework at link time.
// makeRootViewController applies UTM's runtime patches, then presents UTM's SwiftUI VM-list
// UI (UTMSingleWindowView). See Modes/UTM/fork/UTMLauncher.swift.
@interface UTMLauncher : NSObject
+ (UIViewController * _Nonnull)makeRootViewController;
@end

// Yattee mode — same forward-declared pattern. YatteeLauncher is an @objc(YatteeLauncher) Swift
// class inside Yattee.framework; forward-declaring it (not `import Yattee`) keeps OpenClaw's Swift
// from loading Yattee's module graph (MPVKit, SDWebImage, Siesta, Defaults, …). The class is
// resolved from the embedded Yattee.framework at link time. makeRootViewController runs Yattee's
// startup configuration (image pipeline, account/instance setup) then presents its real SwiftUI
// UI (ContentView). See Modes/Yattee/fork/YatteeLauncher.swift.
@interface YatteeLauncher : NSObject
+ (UIViewController * _Nonnull)makeRootViewController;
@end
