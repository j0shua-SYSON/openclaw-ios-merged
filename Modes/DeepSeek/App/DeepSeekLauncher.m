#import "DeepSeekLauncher.h"

#import "DSRootViewController.h"

@implementation DeepSeekLauncher

+ (UIViewController *)makeRootViewController {
    // Mirror what DSAppDelegate did on launch, minus the UIWindow: OpenClaw owns
    // presentation. The reconstruction's original main.m / DSAppDelegate (which
    // called UIApplicationMain and created their own window) are intentionally
    // left out of the framework — a framework has no @main, and embedded the mode
    // is handed a container by OpenClaw.
    DSRootViewController *root = [[DSRootViewController alloc] init];
    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:root];
    navigation.navigationBar.prefersLargeTitles = YES;
    return navigation;
}

@end
