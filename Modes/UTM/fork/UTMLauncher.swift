//
//  UTMLauncher.swift
//  UTM (forked into UTM.framework for OpenClaw)
//
//  @objc boundary OpenClaw calls to enter the UTM SE mode. OpenClaw reaches this via a
//  forward-declared ObjC `UTMLauncher` (see OpenClaw's bridging header) rather than
//  `import UTM`, so OpenClaw's Swift never drags in UTM's large transitive module graph
//  (QEMUKit, CocoaSpice, SwiftUI VM machinery, …) — the same boundary technique used for
//  Delta/Feather.
//
//  Reproduces the non-JIT portion of `Main.main()` (Platform/Main.swift) plus `UTMApp`'s
//  root scene: UTM SE has no JIT, so the whole jailbreak/JIT probe block is skipped. What
//  remains is UTMPatches.patchAll(), Settings.bundle defaults registration, TipKit config,
//  then presenting `UTMSingleWindowView(data: UTMData())` in a UIHostingController.
//
//  Compiles INSIDE UTM's own Swift module (module name kept "UTM"), so it can touch UTM's
//  internal types (UTMData, UTMSingleWindowView, UTMPatches) directly.
//

import SwiftUI
import UIKit
#if canImport(TipKit)
import TipKit
#endif

@objc(UTMLauncher)
public final class UTMLauncher: NSObject {
    private static var didSetup = false

    /// Builds UTM's real SwiftUI VM-list UI for OpenClaw to present as a mode. Safe to call
    /// more than once — one-time setup is guarded so repeated mode switches don't repeat it.
    @objc @MainActor
    public static func makeRootViewController() -> UIViewController {
        self.setupOnce()
        let data = UTMData()
        let root = UTMSingleWindowView(data: data)
        return UIHostingController(rootView: root)
    }

    @MainActor
    private static func setupOnce() {
        guard !self.didSetup else { return }
        self.didSetup = true

        // Runtime patches UTM applies before the UI comes up (Main.main()).
        UTMPatches.patchAll()

        // Register the Settings.bundle defaults. Standalone UTM reads Settings.bundle from
        // Bundle.main; embedded, Bundle.main is OpenClaw, so read it from the framework bundle.
        self.registerDefaultsFromSettingsBundle()

        if #available(iOS 17, *) {
            try? Tips.configure()
        }
    }

    /// Mirrors Main.registerDefaultsFromSettingsBundle(), but sourced from the framework
    /// bundle (where UTM.framework ships Settings.bundle) instead of Bundle.main.
    @MainActor
    private static func registerDefaultsFromSettingsBundle() {
        let bundle = Bundle(for: UTMLauncher.self)
        guard let settingsURL = bundle.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
              let settings = NSDictionary(contentsOf: settingsURL),
              let preferences = settings["PreferenceSpecifiers"] as? [NSDictionary]
        else { return }

        var defaults: [String: Any] = [:]
        for spec in preferences {
            if let key = spec["Key"] as? String, let value = spec["DefaultValue"] {
                defaults[key] = value
            }
        }
        UserDefaults.standard.register(defaults: defaults)
    }
}
