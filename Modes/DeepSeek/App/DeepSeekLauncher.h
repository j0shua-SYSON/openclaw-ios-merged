#import <UIKit/UIKit.h>

/// Entry point OpenClaw uses to present the DeepSeek mode. Compiled inside
/// DeepSeekMode.framework and reached from OpenClaw through a bare forward
/// declaration in OpenClaw-Bridging-Header.h (never `import DeepSeekMode`), so
/// the catalog's C++ never enters OpenClaw's Swift module scan.
@interface DeepSeekLauncher : NSObject

/// A UINavigationController wrapping DSRootViewController — the reconstruction's
/// Chat / Pseudocode / About shell. A nav controller (not the bare VC) because
/// the Pseudocode tab pushes a detail view onto `self.navigationController`.
+ (UIViewController * _Nonnull)makeRootViewController;

@end
