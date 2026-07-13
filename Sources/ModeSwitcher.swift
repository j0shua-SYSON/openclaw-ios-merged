import Observation
import SwiftUI
import UIKit

// MARK: - Mode model

/// A switchable "mode" reachable from the hidden switcher panel. In this phase
/// every mode renders a placeholder; real emulator/app modes are wired in later
/// phases, each backed by its own embedded framework and isolated data dir.
struct AppMode: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String

    /// The modes the switcher offers. Order = display order.
    static let registry: [AppMode] = [
        AppMode(id: "delta", title: "Delta", subtitle: "NES · SNES · N64 · GB · GBA · DS · Genesis", systemImage: "gamecontroller"),
        AppMode(id: "folium", title: "Folium", subtitle: "DS · PS1 · GB/GBC · GBA", systemImage: "leaf.fill"),
        AppMode(id: "ish", title: "iSH", subtitle: "Linux shell (x86 emulation)", systemImage: "terminal"),
        AppMode(id: "feather", title: "Feather", subtitle: "On-device app signing & install", systemImage: "signature"),
        AppMode(id: "utm", title: "UTM SE", subtitle: "Virtual machines (QEMU, JIT-less)", systemImage: "desktopcomputer"),
        AppMode(id: "dolphin", title: "DolphiniOS", subtitle: "GameCube · Wii", systemImage: "gamecontroller.fill"),
    ]
}

// MARK: - Per-mode storage isolation

/// Each mode gets its own subdirectory under Documents so their files never
/// collide in the Files app. Real modes redirect their single data chokepoint
/// (verified per app) to `ModeStorage.directory(for:)`.
enum ModeStorage {
    static func directory(for mode: AppMode) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent(mode.id, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Mode manager

@MainActor
@Observable
final class ModeManager {
    var panelVisible = false
    var activeMode: AppMode?
    let modes: [AppMode]

    init(modes: [AppMode] = AppMode.registry) {
        self.modes = modes
    }

    func togglePanel() {
        self.panelVisible.toggle()
    }

    /// Switch to `mode` (nil = back to the OpenClaw host) and hide the panel.
    func activate(_ mode: AppMode?) {
        self.activeMode = mode
        self.panelVisible = false
    }
}

// MARK: - Secret gesture installer (5 taps · 3 fingers, on the key window)

/// Installs a tap recognizer directly on the host `UIWindow` so the gesture is
/// recognized everywhere — including while a mode is presented full-screen.
struct SecretGestureInstaller: UIViewRepresentable {
    var onTrigger: () -> Void

    func makeUIView(context _: Context) -> SecretGestureInstallerView {
        let view = SecretGestureInstallerView()
        view.onTrigger = self.onTrigger
        // The view itself captures nothing; the recognizer lives on the window.
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SecretGestureInstallerView, context _: Context) {
        uiView.onTrigger = self.onTrigger
    }
}

final class SecretGestureInstallerView: UIView {
    var onTrigger: (() -> Void)?

    private weak var installedWindow: UIWindow?
    private var recognizer: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard let window else {
            self.detach()
            return
        }
        if self.installedWindow === window { return }
        self.detach()

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleGesture))
        recognizer.numberOfTapsRequired = 5
        recognizer.numberOfTouchesRequired = 3
        // Never swallow normal touches; this is a passive overlay recognizer.
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        window.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
        self.installedWindow = window
    }

    private func detach() {
        if let recognizer, let installedWindow {
            installedWindow.removeGestureRecognizer(recognizer)
        }
        self.recognizer = nil
        self.installedWindow = nil
    }

    @objc private func handleGesture() {
        self.onTrigger?()
    }
}

// MARK: - Switcher panel

struct ModeSwitcherPanel: View {
    @Bindable var manager: ModeManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed backdrop — tap to dismiss (same as re-doing the gesture).
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) { self.manager.togglePanel() }
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                Text("Switch app")
                    .font(OpenClawType.title2SemiBold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 8) {
                        self.row(
                            title: "OpenClaw",
                            subtitle: "Home",
                            systemImage: "house",
                            isActive: self.manager.activeMode == nil)
                        {
                            withAnimation(.spring(duration: 0.3)) { self.manager.activate(nil) }
                        }

                        Divider().padding(.vertical, 4)

                        ForEach(self.manager.modes) { mode in
                            self.row(
                                title: mode.title,
                                subtitle: mode.subtitle,
                                systemImage: mode.systemImage,
                                isActive: self.manager.activeMode == mode)
                            {
                                withAnimation(.spring(duration: 0.3)) { self.manager.activate(mode) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                Text("5 taps · 3 fingers to hide")
                    .font(OpenClawType.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 460)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(8)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private func row(
        title: String,
        subtitle: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(isActive ? OpenClawBrand.accent : Color.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(OpenClawType.headline)
                    Text(subtitle)
                        .font(OpenClawType.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OpenClawBrand.accent)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? OpenClawBrand.accent.opacity(0.12) : Color.secondary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode container (placeholder until real modes are embedded)

struct ModeContainerView: View {
    let mode: AppMode
    var onExit: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: self.mode.systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(OpenClawBrand.accent)

                Text(self.mode.title)
                    .font(OpenClawType.title1)

                Text("Placeholder mode. \(self.mode.title) is embedded in a later phase.")
                    .font(OpenClawType.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 4) {
                    Text("Isolated data directory")
                        .font(OpenClawType.captionSemiBold)
                        .foregroundStyle(.secondary)
                    Text(ModeStorage.directory(for: self.mode).path)
                        .font(OpenClawType.monoSmall)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)

                Button {
                    withAnimation(.spring(duration: 0.3)) { self.onExit() }
                } label: {
                    Text("Return to OpenClaw")
                        .font(OpenClawType.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(OpenClawBrand.accent, in: Capsule())
                        .foregroundStyle(OpenClawBrand.accentForeground)
                }
                .padding(.top, 8)
            }
        }
    }
}
