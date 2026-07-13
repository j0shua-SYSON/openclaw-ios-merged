//
//  DeltaLauncher.h
//
//  Pure Objective-C boundary between OpenClaw and Delta.framework. OpenClaw
//  imports THIS header (via its bridging header) instead of `import Delta`, so it
//  never loads Delta's Swift module — which statically links ~12 Swift/Clang
//  dependencies with no shipped module interfaces and would otherwise fail with
//  "missing required modules". The surface here is deliberately UIKit-only.
//
//  Copied into the Delta clone as Delta/DeltaLauncher.h by apply_fork.sh and
//  promoted to a public framework header; the implementation bridges to the
//  @objc Swift `DeltaHost`.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeltaLauncher : NSObject

/// Builds Delta's real root view controller (games library / emulation). Call on
/// the main thread. Backed by DeltaHost.makeRootViewController().
+ (UIViewController *)makeRootViewController;

@end

NS_ASSUME_NONNULL_END
