//
//  FeatherHost.swift
//  Feather (forked into Feather.framework for OpenClaw)
//
//  Feather normally boots as a SwiftUI `@main App` (FeatherApp) with a
//  UIApplicationDelegateAdaptor. When embedded as Feather.framework inside
//  OpenClaw there is no Feather app lifecycle, so this factory runs the launch
//  steps AppDelegate.didFinishLaunching performs (Nuke pipeline, Documents dirs,
//  cache reset, default certificate import) and wraps Feather's real root view
//  (VariedTabbarView, with the Core Data context — the ONLY dependency the app
//  injects at the App level) in a UIHostingController for OpenClaw to present.
//
//  `@objc` on purpose: OpenClaw reaches Feather through the pure-ObjC
//  `FeatherLauncher` shim (forward-declared in OpenClaw's bridging header), NOT
//  via `import Feather`. Feather's Swift module statically links Vapor + the full
//  SwiftNIO stack + Zsign + OpenSSL etc. with no shipped module interfaces, so a
//  Swift `import Feather` from OpenClaw would fail with "missing required
//  modules". Crossing the boundary in ObjC never loads Feather's Swift module.
//
//  Compiles inside Feather's own module (module name kept as "Feather"), so it can
//  touch Feather's internal types directly.
//

import UIKit
import SwiftUI

@objc(FeatherHost)
public final class FeatherHost: NSObject
{
    private static var didLaunch = false

    /// Builds Feather's real UI (Sources / Library / Settings / Certificates tabs).
    /// Safe to call more than once — launch side effects run once.
    @objc @MainActor
    public static func makeRootViewController() -> UIViewController
    {
        if !self.didLaunch
        {
            self.didLaunch = true
            // Mirror FeatherApp's AppDelegate: pipeline + dirs + cache reset + default certs.
            _ = AppDelegate().application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        }

        return UIHostingController(rootView: FeatherRootView())
    }
}

/// Feather's root view, mirroring FeatherApp.body minus the app-lifecycle-only
/// modifiers (deep-link `.onOpenURL`, heartbeat alert, tint/style tweaks) that
/// don't apply when hosted inside OpenClaw's scene. The one hard dependency —
/// the Core Data context — is injected, exactly as FeatherApp does.
private struct FeatherRootView: View
{
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some View
    {
        VStack
        {
            DownloadHeaderView(downloadManager: self.downloadManager)
            VariedTabbarView()
                .environment(\.managedObjectContext, Storage.shared.context)
        }
    }
}
