import Foundation
import SmartTubeIOSCore

// MARK: - Comments
//
// Shared between PlaybackViewModel (standard player) and TOSPlayerViewModel
// (TOS player) — both fetched top-level comments via InnerTubeAPI with an
// identical "skip if already loaded or in flight" guard. `videoId` is
// supplied per call so each adapter can keep its own video-id resolution
// (`(vm.playerInfo?.video ?? video).id` vs. `self.videoId`).

/// Fetches and caches top-level comments for a video.
@MainActor
@Observable
final class CommentsController {

    private(set) var comments: [Comment] = []
    private(set) var isLoading = false

    private let api: InnerTubeAPI
    private let logError: (String) -> Void

    init(api: InnerTubeAPI, logError: @escaping (String) -> Void = { _ in }) {
        self.api = api
        self.logError = logError
    }

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Fetches top-level comments for `videoId`. No-op if already loaded or in flight.
    func load(videoId: String) {
        guard comments.isEmpty, !isLoading else { return }
        isLoading = true
        loadTask = Task {
            do {
                let fetched = try await api.fetchComments(videoId: videoId)
                if !Task.isCancelled { comments = fetched }
            } catch {
                logError("fetchComments failed: \(String(describing: error))")
            }
            if !Task.isCancelled { isLoading = false }
        }
    }

    /// Clears state so the next `load(videoId:)` fetches fresh. PlaybackViewModel is
    /// reused across videos (playNext/playPrevious/autoplay); without this the
    /// `comments.isEmpty` guard above pins the first video's comments for the VM's
    /// whole lifetime. (TOSPlayerViewModel creates a new controller per video.)
    func reset() {
        loadTask?.cancel()
        loadTask = nil
        comments = []
        isLoading = false
    }
}
