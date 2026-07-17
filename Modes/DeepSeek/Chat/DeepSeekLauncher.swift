import SwiftUI
import UIKit

/// Entry point OpenClaw uses to present the DeepSeek mode. Reached from OpenClaw
/// through a bare forward declaration in OpenClaw-Bridging-Header.h (never
/// `import DeepSeekMode`), resolved from the embedded framework at link time via
/// the ObjC runtime — so OpenClaw's Swift never loads this module.
@objc(DeepSeekLauncher)
public final class DeepSeekLauncher: NSObject {
    @objc public static func makeRootViewController() -> UIViewController {
        let host = UIHostingController(rootView: DeepSeekRootView())
        let nav = UINavigationController(rootViewController: host)
        nav.navigationBar.prefersLargeTitles = false
        return nav
    }
}
