//
//  YatteeLauncher.swift
//  Yattee (forked into Yattee.framework for OpenClaw)
//
//  @objc boundary OpenClaw calls to enter the Yattee mode. OpenClaw reaches this via a
//  forward-declared ObjC `YatteeLauncher` rather than `import Yattee`, so OpenClaw's Swift never
//  drags in Yattee's module graph (MPVKit, SDWebImage, Siesta, Defaults, …). Compiles INSIDE
//  Yattee's own module, so it can touch Yattee's internal types (ContentView, PersistenceController,
//  the *Model singletons) directly.
//
//  Reproduces what `@main struct YatteeApp` does (Shared/YatteeApp.swift): present `ContentView()`
//  with the Core Data context + navigation style, forward the app foreground/background
//  notifications to PlayerModel, and run the one-time `configure()` work — none of which happens
//  once @main is neutralized. The settings/data migrations from configure() are intentionally
//  skipped: they upgrade state from older standalone installs, which an embedded first-run has none of.
//
import Defaults
import PINCache
import SDWebImage
import SDWebImageWebPCoder
import Siesta
import SwiftUI
import UIKit

@objc(YatteeLauncher)
public final class YatteeLauncher: NSObject {
    private static var didSetup = false

    /// Builds Yattee's real SwiftUI UI for OpenClaw to present as a mode. Safe to call more than
    /// once — the one-time setup is guarded so repeated mode switches don't repeat it.
    @objc @MainActor
    public static func makeRootViewController() -> UIViewController {
        self.setupOnce()
        return UIHostingController(rootView: YatteeModeRootView())
    }

    /// Mirrors YatteeApp.configure()'s essential startup work (minus the legacy migrations).
    @MainActor
    private static func setupOnce() {
        guard !self.didSetup else { return }
        self.didSetup = true

        // Image pipeline (thumbnails): WebP coder + the PINCache-backed image cache.
        SDImageCodersManager.shared.addCoder(SDImageAWebPCoder.shared)
        SDWebImageManager.defaultImageCache = PINCache(name: "stream.yattee.app")

        // Yattee routes to its startup tab only once the account/instance finishes configuring.
        NotificationCenter.default.addObserver(
            forName: .accountConfigurationComplete,
            object: nil,
            queue: .main
        ) { _ in
            let startupSection = Defaults[.startupSection]
            NavigationModel.shared.tabSelection = startupSection.tabSelection ?? .search
        }

        if !Defaults[.lastAccountIsPublic] {
            AccountsModel.shared.configureAccount()
        }

        if let countryOfPublicInstances = Defaults[.countryOfPublicInstances] {
            InstancesManifest.shared.setPublicAccount(
                countryOfPublicInstances,
                asCurrent: AccountsModel.shared.current.isNil
            )
        }

        if !AccountsModel.shared.current.isNil {
            PlayerModel.shared.restoreQueue()
        }

        PlaylistsModel.shared.load()
        PlayerModel.shared.updateRemoteCommandCenter()

        // Initialize UserAgentManager (Yattee does this at startup).
        _ = UserAgentManager.shared

        DispatchQueue.global(qos: .userInitiated).async {
            URLBookmarkModel.shared.refreshAll()
        }
    }
}

/// Yattee's root, wired the way YatteeApp's WindowGroup wires it.
private struct YatteeModeRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var navigationStyle: NavigationStyle {
        horizontalSizeClass == .compact ? .tab : .sidebar
    }

    var body: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environment(\.navigationStyle, self.navigationStyle)
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                PlayerModel.shared.handleEnterForeground()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            ) { _ in
                PlayerModel.shared.handleEnterBackground()
            }
    }
}
