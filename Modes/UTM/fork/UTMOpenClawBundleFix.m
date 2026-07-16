//
//  UTMOpenClawBundleFix.m — OpenClaw embed shim for UTM.framework
//
//  UTM's own resources (Assets.car asset catalog, Settings.bundle) are compiled INTO
//  UTM.framework, but UTM's code looks them up in +[NSBundle mainBundle]. When UTM runs as a
//  standalone app that's fine (mainBundle == UTM). Embedded in OpenClaw, mainBundle is the
//  HOST app, which doesn't contain UTM's resources — so two lookups hard-crash:
//
//    1. VMWizardOSView: `UIImage(named: "Logo-Linux")!` → nil (asset not in host) → force
//       unwrap trap (EXC_BREAKPOINT) when opening "Create VM".
//    2. IASKAppSettingsViewController (InAppSettingsKit): its reader loads Settings.bundle
//       from mainBundle and throws an NSException (SIGABRT) when opening Settings.
//
//  Rather than patch 100+ call sites, redirect the two lookups to UTM.framework's bundle via
//  runtime swizzles installed at framework load (+load). Both are host-safe: the UIImage
//  swizzle tries the main bundle FIRST and only falls back to UTM's bundle on a miss, so
//  OpenClaw's own image lookups are unchanged; the IASK reader is used only by UTM.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSBundle *OpenClawUTMBundle(void) {
    // UTMLauncher is @objc(UTMLauncher) and lives in UTM.framework, so bundleForClass: resolves
    // to the framework bundle.
    Class c = NSClassFromString(@"UTMLauncher");
    NSBundle *b = c ? [NSBundle bundleForClass:c] : nil;
    return b ?: [NSBundle mainBundle];
}

#pragma mark - UIImage(named:) → UTM.framework asset catalog fallback

@implementation UIImage (OpenClawUTMBundle)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method orig = class_getClassMethod(self, @selector(imageNamed:));
        Method repl = class_getClassMethod(self, @selector(openclaw_utm_imageNamed:));
        if (orig && repl) {
            method_exchangeImplementations(orig, repl);
        }
    });
}

+ (UIImage *)openclaw_utm_imageNamed:(NSString *)name {
    // After the exchange this selector points at the ORIGINAL +imageNamed: (main-bundle lookup).
    UIImage *image = [self openclaw_utm_imageNamed:name];
    if (image != nil) {
        return image;
    }
    // Miss in the host bundle — try UTM.framework's asset catalog. This selector is a different
    // method (not swizzled), so there is no recursion.
    return [UIImage imageNamed:name inBundle:OpenClawUTMBundle() compatibleWithTraitCollection:nil];
}

@end

#pragma mark - IASKSettingsReader initWithFile: → UTM.framework Settings.bundle

@interface OpenClawIASKBundleFix : NSObject
@end

@implementation OpenClawIASKBundleFix

+ (void)load {
    Class reader = NSClassFromString(@"IASKSettingsReader");
    if (reader == Nil) {
        return;
    }
    Method m = class_getInstanceMethod(reader, @selector(initWithFile:));
    if (m == NULL) {
        return;
    }
    // -[IASKSettingsReader initWithFile:] normally forwards to initWithFile:bundle: with
    // NSBundle.mainBundle. Replace it so UTM's Settings.bundle is resolved from the framework.
    IMP newImp = imp_implementationWithBlock(^id(id self_, NSString *file) {
        SEL twoArg = @selector(initWithFile:bundle:);
        IMP imp = [self_ methodForSelector:twoArg];
        if (imp == NULL) {
            return self_;
        }
        id (*init2)(id, SEL, NSString *, NSBundle *) = (id (*)(id, SEL, NSString *, NSBundle *))imp;
        return init2(self_, twoArg, file, OpenClawUTMBundle());
    });
    method_setImplementation(m, newImp);
}

@end
