//
//  DeltaHost.swift
//  DeltaMode
//
//  Added by the OpenClaw merge fork. Delta normally boots through its own
//  UIApplication / scene lifecycle (AppDelegate + SceneDelegate + Main.storyboard).
//  When embedded as DeltaMode.framework inside OpenClaw there is no Delta app
//  lifecycle, so this factory performs the minimal launch setup that
//  AppDelegate.didFinishLaunchingWithOptions would do (register defaults + cores)
//  and then hands back Delta's storyboard root view controller for OpenClaw to
//  present as a mode.
//
//  NOTE: this file compiles inside Delta's own Swift module (PRODUCT_MODULE_NAME
//  is kept as "Delta" so storyboards' customModule="Delta" and the scene manifest
//  keep resolving), hence it can touch Delta's internal types directly.
//

import UIKit
import DeltaCore

public enum DeltaHost
{
    private static var didRegisterCores = false

    /// Builds Delta's real UI (LaunchViewController → GameViewController, with the
    /// games library presented over it). Safe to call more than once — core
    /// registration is guarded so repeated mode switches don't double-register.
    @MainActor
    public static func makeRootViewController() -> UIViewController
    {
        self.prepare()

        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: LaunchViewController.self))
        guard let rootViewController = storyboard.instantiateInitialViewController() else
        {
            fatalError("DeltaMode: Main.storyboard has no initial view controller.")
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
