//
//  FeatherLauncher.h
//
//  Pure Objective-C boundary between OpenClaw and Feather.framework. OpenClaw
//  forward-declares this class in its bridging header (it does NOT import
//  <Feather/…>), so OpenClaw's Swift never loads Feather's Swift module and its
//  statically-linked transitive dependencies (Vapor, SwiftNIO, Zsign, OpenSSL, …)
//  which ship no module interfaces. The class is resolved from the embedded
//  Feather.framework at link time. Surface is deliberately UIKit-only.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FeatherLauncher : NSObject

/// Builds Feather's real root view controller (signing UI). Call on the main
/// thread. Backed by FeatherHost.makeRootViewController().
+ (UIViewController *)makeRootViewController;

@end

NS_ASSUME_NONNULL_END
