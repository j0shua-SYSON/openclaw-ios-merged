//
//  SmartTubeLauncher.swift
//
//  Entry point OpenClaw calls to present the SmartTube (YouTube) mode. SmartTubeIOS is a Swift
//  package (github.com/milika/SmartTubeIOS), forked only to drop FirebaseCrashlytics; after that
//  its only dependency is the Foundation-based SmartTubeIOSCore, so `import`-ing it here is cheap
//  and doesn't drag a heavy transitive module graph (the reason the emulator modes use the
//  forward-declared @objc launcher pattern instead).
//
//  This reproduces the iOS setup that SmartTube's own app entry (AppEntry) performs: it builds
//  the shared InnerTubeAPI (po_token via the bundled BotGuard JS solver), the services and view
//  models, injects all of them into RootView's environment (every @Observable it reads is
//  required — a missing one is a hard SwiftUI crash), and wraps the result in a
//  UIHostingController. po_token JS + localizations load via Bundle.module (the package's own
//  resource bundle), so there is no Bundle.main problem.
//
import UIKit
import SwiftUI
import SmartTubeIOS
import SmartTubeIOSCore

enum SmartTubeLauncher {
    @MainActor
    static func makeRootViewController() -> UIViewController {
        let settingsStore = SettingsStore()
        // po_token is solved on-device by running YouTube's BotGuard solver JS in JavaScriptCore.
        let api = InnerTubeAPI(authToken: nil, poTokenProvider: BotGuardClient())
        let authService = AuthService()
        let browseViewModel = BrowseViewModel(api: api)
        let playerStateStore = PlayerStateStore(api: api)
        let tosPlayerStateStore = TOSPlayerStateStore()
        let playerRouter = PlayerRouter(
            playerState: playerStateStore,
            tosState: tosPlayerStateStore,
            settingsStore: settingsStore
        )
        let cardDownloadService = VideoDownloadService(api: api)

        let root = RootView()
            .environment(authService)
            .environment(browseViewModel)
            .environment(settingsStore)
            .environment(\.innerTubeAPI, api)          // must be explicit — the key has a silent default
            .environment(cardDownloadService)
            .environment(playerStateStore)
            .environment(tosPlayerStateStore)
            .environment(playerRouter)
            .onChange(of: authService.accessToken, initial: true) { _, newToken in
                playerStateStore.vm.updateAuthToken(newToken)
                Task {
                    await api.setAuthToken(newToken)
                    await browseViewModel.updateAuthToken(newToken)
                }
            }
            .onChange(of: authService.sapisid, initial: true) { _, newSapisid in
                playerStateStore.vm.updateSAPISID(newSapisid)
                Task { await api.setSAPISID(newSapisid) }
            }
            .onChange(of: settingsStore.settings.enabledSections) { _, newSections in
                browseViewModel.configureSections(newSections)
            }
            .onChange(of: settingsStore.settings.historyState, initial: true) { _, newState in
                browseViewModel.updateHistoryEnabled(newState == .enabled)
            }

        return UIHostingController(rootView: root)
    }
}
