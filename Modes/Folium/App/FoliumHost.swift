//
//  FoliumHost.swift
//  FoliumMode
//
//  Public entry point for hosting Folium's game library inside OpenClaw.
//  Folium's app-layer types (TabController / GamesManager / DirectoryManager) are
//  internal, so this bridge — compiled INTO the FoliumMode target — exposes a clean
//  public API that returns a UIViewController the host can present.
//

import UIKit

import Grape
import Kiwi
import Mandarine
import Tomato

public enum FoliumHost {
    /// Builds Folium's root view controller (the game-library `TabController`), fully
    /// bootstrapped, mirroring what Folium's own `SceneDelegate` does on launch.
    /// The returned controller strongly retains the systems via `GamesManager`, so
    /// emulation stays alive for as long as the mode is presented.
    @MainActor
    public static func makeRootViewController() -> UIViewController {
        // Skip Folium's first-run camera-permission onboarding; go straight to the library.
        UserDefaults.standard.set(true, forKey: "folium.onboardingComplete")

        let grapeSystem = GrapeSystem()
        let kiwiSystem = KiwiSystem()
        let mandarineSystem = MandarineSystem()
        let tomatoSystem = TomatoSystem()
        let directoryManager = DirectoryManager()

        let gamesManager = GamesManager(
            grapeSystem: grapeSystem,
            kiwiSystem: kiwiSystem,
            mandarineSystem: mandarineSystem,
            tomatoSystem: tomatoSystem)

        let controller = TabController(gamesManager: gamesManager)

        // Replicate SceneDelegate's async bootstrap of on-disk directories + cores.
        Task {
            try? await directoryManager.initializeSystemDirectoriesForInitialLaunch()
            await grapeSystem.initializePaths()
            await grapeSystem.initializeSystem()
            await kiwiSystem.initializePaths()
            await kiwiSystem.initializeSystem()
            await mandarineSystem.initializePaths()
            await mandarineSystem.initializeMemoryCards()
            await mandarineSystem.initializeSystem()
            await tomatoSystem.initializeSystem()
            await tomatoSystem.initializePaths()
        }

        return controller
    }
}
