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
