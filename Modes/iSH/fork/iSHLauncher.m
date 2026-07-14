//
//  iSHLauncher.m
//  iSH (forked into iSH.framework for OpenClaw)
//

#import "iSHLauncher.h"
#import "AppDelegate.h"
#import "ExceptionExfiltrator.h"

// -boot is private to AppDelegate.m. iSH normally runs it from
// -application:willFinishLaunchingWithOptions:, which never fires when iSH is embedded
// (there is no app lifecycle), so iSHLauncher drives the boot itself. Forward-declare it.
@interface AppDelegate (iSHLauncherBoot)
- (int)boot;
@end

@implementation iSHLauncher

// Retain the AppDelegate that owns the boot's process-global state (network
// reachability, exit/die hooks) for the life of the process.
static AppDelegate *gBootDelegate;

+ (void)bootOnce {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSSetUncaughtExceptionHandler(iSHExceptionHandler);
        gBootDelegate = [AppDelegate new];
        // Mounts the (isolated) rootfs, wires devices, and task_start()s Alpine's init.
        // On first launch this also extracts root.tar.gz from the framework bundle into
        // Documents/iSH/roots, so it can take a few seconds.
        int err = [gBootDelegate boot];
        if (err < 0)
            NSLog(@"[iSH] kernel boot failed: %d", err);
    });
}

+ (UIViewController *)makeRootViewController {
    // Boot the emulated Linux kernel before showing the terminal: iSH's
    // TerminalViewController connects to the /dev/console the boot creates.
    [self bootOnce];

    // Terminal.storyboard ships inside iSH.framework; Bundle.main is OpenClaw when embedded.
    NSBundle *bundle = [NSBundle bundleForClass:[iSHLauncher class]];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Terminal" bundle:bundle];
    UIViewController *root = [storyboard instantiateInitialViewController];
    if (root == nil) {
        UIViewController *placeholder = [[UIViewController alloc] init];
        placeholder.view.backgroundColor = UIColor.blackColor;
        return placeholder;
    }
    return root;
}

@end
