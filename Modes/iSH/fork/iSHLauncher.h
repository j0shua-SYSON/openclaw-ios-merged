//
//  iSHLauncher.h
//  iSH (forked into iSH.framework for OpenClaw)
//
//  Pure-ObjC boundary OpenClaw calls to enter the iSH mode. iSH is an all-ObjC/C
//  app, so unlike Delta/Feather there is no Swift module to avoid importing — but we
//  keep a single, minimal public entry point so OpenClaw only needs UIKit.
//
//  Milestone 1b: returns the Terminal storyboard's root VC from the framework bundle.
//  Milestone 2 adds the kernel boot (mount_root + task_start) with the rootfs isolated
//  to Documents/iSH before the terminal is shown.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface iSHLauncher : NSObject

/// Boots iSH (once, guarded) and returns its Terminal view controller for OpenClaw
/// to present as a mode.
+ (UIViewController *)makeRootViewController;

@end

NS_ASSUME_NONNULL_END
