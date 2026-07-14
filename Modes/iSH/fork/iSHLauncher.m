//
//  iSHLauncher.m
//  iSH (forked into iSH.framework for OpenClaw)
//

#import "iSHLauncher.h"

@implementation iSHLauncher

+ (UIViewController *)makeRootViewController {
    // Terminal.storyboard ships inside iSH.framework. When iSH runs standalone the
    // storyboard loads from Bundle.main; embedded, Bundle.main is OpenClaw, so load it
    // from the framework bundle explicitly.
    NSBundle *bundle = [NSBundle bundleForClass:[iSHLauncher class]];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Terminal" bundle:bundle];
    UIViewController *root = [storyboard instantiateInitialViewController];
    if (root == nil) {
        // Should not happen once the storyboard is bundled; fail soft rather than crash
        // OpenClaw's process during mode entry.
        UIViewController *placeholder = [[UIViewController alloc] init];
        placeholder.view.backgroundColor = UIColor.blackColor;
        return placeholder;
    }
    return root;
}

@end
