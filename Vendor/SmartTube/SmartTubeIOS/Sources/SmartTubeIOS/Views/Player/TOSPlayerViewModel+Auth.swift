#if !os(tvOS)
import Foundation
import SmartTubeIOSCore

// MARK: - Auth Token
//
// Mirrors PlaybackViewModel+Auth.swift exactly. TOSPlayerViewModel owns its own
// InnerTubeAPI instance (TOSPlayerViewModel.swift:132), just like PlaybackViewModel
// does — without this propagation, WatchtimeTracker's pings carry no auth header
// even for signed-in users, so playback through the TOS player (the iOS default
// since 4.6) never registers in YouTube's watch history. Same root cause as
// GitHub issue #51, just never ported to the TOS pipeline (GitHub issue #78).

extension TOSPlayerViewModel {

    /// Propagates the auth token to this view model's own API instance so
    /// WatchtimeTracker sends authenticated watch-time pings.
    public func updateAuthToken(_ token: String?) {
        // No-op when unchanged: TOSPlayerView.onAppear re-fires on every expand from
        // the mini-player with the same token, and the tracking URLs cleared below are
        // only resolved once per session (beginWatchtimeTracking's one-shot "ready"
        // message) — re-clearing them mid-session would leave the rest of the session's
        // watch-history pings without their account binding.
        guard token != appliedAuthToken else { return }
        appliedAuthToken = token
        Task { await api.setAuthToken(token) }
        Task { await VideoPreloadCache.shared.setAuthToken(token) }
        // Any tracking URLs already fetched (or in-flight) may be stale/anonymous —
        // mirrors PlaybackViewModel+Auth.swift's BUG-016 fix.
        tracker.setTrackingURLs(nil)
    }

    /// Propagates the YouTube.com SAPISID cookie so WEB_CREATOR requests use
    /// SAPISIDHASH auth.
    public func updateSAPISID(_ sapisid: String?) {
        guard sapisid != appliedSAPISID else { return }
        appliedSAPISID = sapisid
        Task { await api.setSAPISID(sapisid) }
        Task { await VideoPreloadCache.shared.setSAPISID(sapisid) }
    }
}
#endif // !os(tvOS)
