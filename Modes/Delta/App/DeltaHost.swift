//
//  DeltaHost.swift
//  Delta (forked into Delta.framework for OpenClaw)
//
//  Delta normally boots through its own UIApplication / scene lifecycle
//  (AppDelegate + SceneDelegate + Main.storyboard). When embedded as
//  Delta.framework inside OpenClaw there is no Delta app lifecycle, so this
//  factory performs the minimal launch setup that AppDelegate.didFinishLaunching
//  would do (register defaults + cores) and hands back Delta's storyboard root
//  view controller for OpenClaw to present as a mode.
//
//  This type is `@objc` on purpose: OpenClaw reaches Delta through the pure-ObjC
//  `DeltaLauncher` shim (see DeltaLauncher.h/.m), NOT via `import Delta`. Delta's
//  Swift module statically links ~12 Swift/Clang dependencies (Roxas, Harmony,
//  SQLite, RevenueCat, …) with no shipped module interfaces, so a Swift `import
//  Delta` from OpenClaw fails with "missing required modules". Crossing the
//  boundary in Objective-C (Clang) never loads Delta's Swift module, sidestepping
//  that entirely. DeltaLauncher.m calls the @objc method below.
//
//  NOTE: compiles inside Delta's own Swift module (module name kept as "Delta" so
//  storyboards' customModule + the scene manifest resolve), so it can touch
//  Delta's internal types directly.
//

import UIKit
import DeltaCore

extension Bundle
{
    /// The Delta.framework bundle. Delta ships its resources (storyboards,
    /// openvgdb.sqlite, cheatbase.zip, WhatsNew/Patreon/RevenueCat/Contributors
    /// plists, Profanity.txt, nibs, …) inside the framework, but its code loads
    /// them via `Bundle.main` — which is Delta.app normally but OpenClaw.app when
    /// embedded. apply_fork.sh rewrites those resource lookups to use this instead.
    static var deltaResources: Bundle { Bundle(for: DeltaHost.self) }
}

@objc(DeltaHost)
public final class DeltaHost: NSObject
{
    private static var didRegisterCores = false

    /// Builds Delta's real UI (LaunchViewController → GameViewController, with the
    /// games library presented over it). Safe to call more than once — core
    /// registration is guarded so repeated mode switches don't double-register.
    @objc @MainActor
    public static func makeRootViewController() -> UIViewController
    {
        self.prepare()

        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: LaunchViewController.self))
        guard let rootViewController = storyboard.instantiateInitialViewController() else
        {
            fatalError("Delta: Main.storyboard has no initial view controller.")
        }

        // Delta normally applies its purple tint on the window in configureAppearance();
        // set it on the presented root instead since we bypass Delta's window.
        rootViewController.view.tintColor = UIColor.deltaPurple

        return rootViewController
    }

    @MainActor
    private static func prepare()
    {
        Settings.registerDefaults()

        guard !self.didRegisterCores else { return }
        self.didRegisterCores = true

        // Mirrors AppDelegate.registerCores() under the BETA flag: register every
        // system's core so the full library (NES/SNES/N64/GBC/GBA/DS/Genesis) works.
        System.allCases.forEach { Delta.register($0.deltaCore) }
    }
}
