import SwiftUI
import UIKit

extension Bundle {
    /// The DeepSeekMode framework bundle (for Media.xcassets lookups).
    static let deepSeek = Bundle(for: DeepSeekLauncher.self)
}

/// The base model chosen on the welcome screen (locked once a chat starts, per
/// DeepSeek: "To switch modes, please start a new chat.").
enum DSModel: String, CaseIterable, Identifiable {
    case instant, expert, vision
    var id: String { rawValue }
    var name: String { self == .instant ? "Instant" : self == .expert ? "Expert" : "Vision" }
    var icon: String { self == .instant ? "bolt.fill" : self == .expert ? "diamond" : "photo" }
    var subtitle: String {
        switch self {
        case .instant: return "Instant responses for daily conversations"
        case .expert: return "For complex problems, busy at peak times"
        case .vision: return "image understanding (Beta)"
        }
    }
}

// MARK: - Welcome (empty state)

struct DSWelcomeView: View {
    @Binding var model: DSModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            HStack(spacing: 8) {
                Image("DSWhale", bundle: .deepSeek)
                    .resizable().scaledToFit().frame(height: 26)
                Text("Start chatting with \(model.name)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
            }
            DSModelPicker(model: $model)
            Text(model.subtitle)
                .font(DS.Font.secondary)
                .foregroundStyle(DS.Palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

struct DSModelPicker: View {
    @Binding var model: DSModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DSModel.allCases) { m in
                let selected = m == model
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { model = m }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon).font(.system(size: 13, weight: .semibold))
                        Text(m.name).font(DS.Font.pill)
                    }
                    .foregroundStyle(selected ? DS.Palette.brand : DS.Palette.textPrimary)
                    .padding(.vertical, 9).padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected ? DS.Palette.toggleActiveFill : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Palette.layer2)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Palette.separator, lineWidth: 1))
        )
    }
}

// MARK: - Composer bar

struct DSComposer: View {
    @Binding var text: String
    @Binding var thinkOn: Bool
    @Binding var searchOn: Bool
    var isStreaming: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    @FocusState private var focused: Bool

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Type a message or hold to speak", text: $text, axis: .vertical)
                .font(DS.Font.body)
                .foregroundStyle(DS.Palette.textPrimary)
                .tint(DS.Palette.brand)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                DSToggleChip(title: "Think", systemImage: "atom", isOn: $thinkOn)
                DSToggleChip(title: "Search", systemImage: "globe", isOn: $searchOn)
                Spacer(minLength: 0)
                circleButton(system: "plus", filled: false) {}
                sendButton
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DS.Palette.inputFill)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(DS.Palette.inputBorder, lineWidth: 1))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var sendButton: some View {
        if isStreaming {
            circleButton(system: "stop.fill", filled: true) { onStop() }
        } else if canSend {
            circleButton(system: "arrow.up", filled: true) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSend()
            }
        } else {
            circleButton(system: "waveform", filled: false) {}
        }
    }

    @ViewBuilder private func circleButton(system: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: filled ? 16 : 17, weight: .semibold))
                .foregroundStyle(filled ? Color.white : DS.Palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(filled ? DS.Palette.brand : Color.clear)
                        .overlay(Circle().stroke(filled ? Color.clear : DS.Palette.toggleIdleBorder, lineWidth: 1.2))
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

struct DSToggleChip: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 14, weight: .medium))
                Text(title).font(DS.Font.pill)
            }
            .foregroundStyle(isOn ? DS.Palette.brand : DS.Palette.textPrimary)
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(
                Capsule().fill(isOn ? DS.Palette.toggleActiveFill : Color.clear)
                    .overlay(Capsule().stroke(isOn ? DS.Palette.toggleActiveBorder : DS.Palette.toggleIdleBorder, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
