//
//  CrashlyticsLogger.swift — OpenClaw fork: Firebase-free stub.
//
//  Upstream SmartTubeIOS forwards log breadcrumbs + non-fatals to Firebase Crashlytics. For the
//  OpenClaw embed we drop the firebase-ios-sdk dependency entirely (it needs a
//  GoogleService-Info.plist tied to the app's bundle id, pulls a heavy transitive graph, and
//  would double-link GoogleUtilities against Delta's Google Sign-In). This replacement keeps the
//  exact public API — same initializer + instance methods + static methods/property — backed by
//  os.Logger only, so every call site across the package compiles and logs unchanged. Crash
//  reporting is simply a no-op.
//
import Foundation
import os
import SmartTubeIOSCore

struct CrashlyticsLogger: Sendable {
    /// Short per-session id, surfaced in the Stats-for-Nerds overlay. Kept (no Crashlytics key).
    static let sessionReportID: String = {
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String(raw.prefix(8)).uppercased()
    }()

    private let logger: Logger
    private let category: String

    init(subsystem: String = appSubsystem, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    func notice(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.notice("\(msg, privacy: .public)")
    }

    func error(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.error("\(msg, privacy: .public)")
    }

    func debug(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.debug("\(msg, privacy: .public)")
    }

    func recordNonFatal(_ error: Error, userInfo: [String: String] = [:]) {
        let nsError = error as NSError
        logger.error("[\(self.category, privacy: .public)] \(nsError.domain, privacy: .public)(\(nsError.code)): \(nsError.localizedDescription, privacy: .public)")
    }

    // Static context/report hooks — os.Logger notes only; the Crashlytics side is dropped.
    static func setVideoContext(id: String, title: String) {}

    static func setIntendedVideo(id: String, title: String) {}

    static func sendDiagnosticReport() {}

    static func recordSlowVideoLoad(videoId: String, elapsedMs: Int, streamType: String, hasError: Bool, errorDescription: String? = nil) {}

    static func sendAutoPlaybackDiagnostic() {}

    static func sendWrongVideoReport(intendedId: String, intendedTitle: String, activeId: String, activeTitle: String) {}
}
