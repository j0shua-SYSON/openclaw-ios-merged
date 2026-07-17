import SwiftUI
import UIKit

// MARK: - Model

struct DSMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String = ""
    var thinking: String = ""
    var thinkingSeconds: Int? = nil     // set when the answer starts
    var searchStatus: String? = nil
    var isStreaming: Bool = false
    var thinkingExpanded: Bool = true
    var failed: Bool = false
}

// MARK: - View model

@MainActor
final class DeepSeekChatModel: ObservableObject {
    enum Screen { case auth, chat }

    @Published var screen: Screen
    @Published var messages: [DSMessage] = []
    @Published var input = ""
    @Published var isStreaming = false
    @Published var errorText: String?
    @Published var chatTitle = "New chat"
    @Published var drawerOpen = false

    @Published var model: DSModel = .instant
    @Published var thinkOn = false
    @Published var searchOn = false

    // Auth screen
    @Published var email = ""
    @Published var password = ""
    @Published var signingIn = false

    private var token: String? { didSet { persist() } }
    private var isGuest = false
    private var sessionId: String?
    private var parentMessageID: Int?
    private var streamTask: Task<Void, Never>?
    private let api = DeepSeekAPI.shared

    var accountLabel: String { isGuest ? "Guest" : (email.isEmpty ? "Signed in" : email) }
    var chatStarted: Bool { !messages.isEmpty }

    init() {
        let saved = UserDefaults.standard.string(forKey: "deepseek.token")
        token = saved
        email = UserDefaults.standard.string(forKey: "deepseek.email") ?? ""
        screen = (saved?.isEmpty == false) ? .chat : .auth
    }

    private func persist() {
        UserDefaults.standard.set(token, forKey: "deepseek.token")
        UserDefaults.standard.set(email, forKey: "deepseek.email")
    }

    // MARK: Auth

    func signIn() {
        errorText = nil
        let e = email.trimmingCharacters(in: .whitespaces), p = password
        guard !e.isEmpty, !p.isEmpty else { errorText = "Enter your DeepSeek email and password."; return }
        signingIn = true
        Task {
            do {
                token = try await api.login(email: e, password: p)
                isGuest = false; password = ""
                resetConversation(); screen = .chat
            } catch { errorText = friendly(error) }
            signingIn = false
        }
    }

    func continueAsGuest() { errorText = nil; isGuest = true; token = nil; resetConversation(); screen = .chat }

    func logout() {
        streamTask?.cancel()
        token = nil; isGuest = false; email = ""; resetConversation(); drawerOpen = false; screen = .auth
    }

    // MARK: Chat lifecycle

    func newChat() {
        streamTask?.cancel(); isStreaming = false
        resetConversation()
        withAnimation(.easeInOut(duration: 0.2)) { drawerOpen = false }
    }

    private func resetConversation() {
        messages = []; sessionId = nil; parentMessageID = nil; chatTitle = "New chat"
        thinkOn = false; searchOn = false; model = .instant; errorText = nil
    }

    func stop() { streamTask?.cancel(); streamTask = nil; isStreaming = false
        if let last = messages.indices.last { messages[last].isStreaming = false } }

    func send() {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }
        input = ""; errorText = nil
        if messages.isEmpty { chatTitle = String(prompt.prefix(40)) }
        messages.append(DSMessage(role: .user, text: prompt))
        let idx = messages.count
        messages.append(DSMessage(role: .assistant, isStreaming: true))

        let wantThinking = thinkOn || model == .expert
        let wantSearch = searchOn
        var thinkStart: Date?

        streamTask = Task {
            do {
                let stream: AsyncThrowingStream<DSStreamEvent, Error>
                if isGuest {
                    stream = api.streamGuest(prompt: prompt, thinkingEnabled: wantThinking, searchEnabled: wantSearch)
                } else {
                    guard let token else { throw DeepSeekError(message: "Signed out — please sign in again.") }
                    if sessionId == nil { sessionId = try await api.createSession(token: token) }
                    stream = api.streamAuthed(token: token, sessionId: sessionId!, parentMessageID: parentMessageID,
                                              prompt: prompt, thinkingEnabled: wantThinking, searchEnabled: wantSearch)
                }
                for try await ev in stream {
                    guard idx < messages.count else { break }
                    switch ev {
                    case let .messageID(mid): parentMessageID = mid
                    case let .thinking(t):
                        if thinkStart == nil { thinkStart = Date() }
                        messages[idx].thinking += t
                    case let .answer(a):
                        if let s = thinkStart, messages[idx].thinkingSeconds == nil {
                            messages[idx].thinkingSeconds = max(1, Int(Date().timeIntervalSince(s)))
                            withAnimation(.easeInOut(duration: 0.25)) { messages[idx].thinkingExpanded = false }
                        }
                        messages[idx].text += a
                    case let .searchStatus(s): messages[idx].searchStatus = s
                    }
                }
                if idx < messages.count { messages[idx].isStreaming = false }
            } catch {
                if idx < messages.count {
                    if messages[idx].text.isEmpty && messages[idx].thinking.isEmpty {
                        messages.remove(at: idx)
                    } else { messages[idx].isStreaming = false }
                }
                errorText = friendly(error)
            }
            isStreaming = false
        }
        isStreaming = true
    }

    private func friendly(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
    }
}

// MARK: - Root

struct DeepSeekRootView: View {
    @StateObject private var model = DeepSeekChatModel()

    var body: some View {
        ZStack {
            DS.Palette.bg.ignoresSafeArea()
            switch model.screen {
            case .auth: DSAuthView(model: model)
            case .chat:
                DSChatScreen(model: model)
                DSDrawerOverlay(model: model)
            }
        }
        .tint(DS.Palette.brand)
    }
}

// MARK: - Chat screen

private struct DSChatScreen: View {
    @ObservedObject var model: DeepSeekChatModel

    var body: some View {
        VStack(spacing: 0) {
            DSHeader(
                title: model.chatStarted ? model.chatTitle : "New chat",
                onMenu: { withAnimation(.easeOut(duration: 0.28)) { model.drawerOpen = true } },
                onCompose: { model.newChat() })
            Divider().overlay(DS.Palette.separator)

            ScrollViewReader { proxy in
                ScrollView {
                    if model.chatStarted {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(model.messages) { DSMessageRow(message: $0) }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, DS.Metric.hPad)
                        .padding(.vertical, 14)
                        .frame(maxWidth: DS.Metric.maxContentWidth)
                        .frame(maxWidth: .infinity)
                    } else {
                        DSWelcomeView(model: $model.model)
                            .frame(minHeight: 420)
                            .frame(maxWidth: DS.Metric.maxContentWidth)
                            .frame(maxWidth: .infinity)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.last?.text) { _, _ in scrollDown(proxy) }
                .onChange(of: model.messages.last?.thinking) { _, _ in scrollDown(proxy) }
                .onChange(of: model.messages.count) { _, _ in scrollDown(proxy) }
            }

            if let err = model.errorText {
                Text(err).font(DS.Font.secondary).foregroundStyle(DS.Palette.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Metric.hPad).padding(.top, 4)
                    .frame(maxWidth: DS.Metric.maxContentWidth)
            }

            DSComposer(text: $model.input, thinkOn: $model.thinkOn, searchOn: $model.searchOn,
                       isStreaming: model.isStreaming, onSend: model.send, onStop: model.stop)
                .frame(maxWidth: DS.Metric.maxContentWidth)
                .frame(maxWidth: .infinity)
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }
}

// MARK: - Header

private struct DSHeader: View {
    let title: String
    let onMenu: () -> Void
    let onCompose: () -> Void

    var body: some View {
        HStack {
            Button(action: onMenu) { DSMenuGlyph().frame(width: 24, height: 20) }
                .buttonStyle(.plain).foregroundStyle(DS.Palette.textPrimary)
            Spacer()
            Text(title).font(DS.Font.title).foregroundStyle(DS.Palette.textPrimary)
                .lineLimit(1).truncationMode(.tail).padding(.horizontal, 8)
            Spacer()
            Button(action: onCompose) { Image(systemName: "square.and.pencil").font(.system(size: 19)) }
                .buttonStyle(.plain).foregroundStyle(DS.Palette.textPrimary)
        }
        .padding(.horizontal, DS.Metric.hPad).padding(.vertical, 10)
    }
}

/// DeepSeek's menu icon: three left-aligned, staggered-length lines.
private struct DSMenuGlyph: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().frame(width: 22, height: 2)
            Capsule().frame(width: 14, height: 2)
            Capsule().frame(width: 18, height: 2)
        }
    }
}

// MARK: - Message rows

private struct DSMessageRow: View {
    let message: DSMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack { Spacer(minLength: 44); DSUserBubble(text: message.text) }
        case .assistant:
            DSAssistantView(message: message)
        }
    }
}

private struct DSUserBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DS.Font.body).foregroundStyle(DS.Palette.userBubbleText)
            .textSelection(.enabled)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(DS.Palette.userBubble, in: RoundedRectangle(cornerRadius: DS.Metric.bubbleRadius, style: .continuous))
    }
}

private struct DSAssistantView: View {
    let message: DSMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let status = message.searchStatus {
                Label(status, systemImage: "globe").font(DS.Font.secondary).foregroundStyle(DS.Palette.textTertiary)
            }
            if !message.thinking.isEmpty || (message.isStreaming && message.thinkingSeconds == nil && message.text.isEmpty && message.thinking.isEmpty == false) {
                DSReasoningBlock(message: message)
            }
            if !message.text.isEmpty {
                DSMarkdownView(text: message.text)
            }
            if message.isStreaming && message.text.isEmpty && message.thinking.isEmpty {
                DSTypingDots()
            } else if message.isStreaming && !message.text.isEmpty {
                DSCaret()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Reasoning ("Thought for N seconds")

private struct DSReasoningBlock: View {
    let message: DSMessage
    @State private var expanded = true

    private var header: String {
        if let s = message.thinkingSeconds { return "Thought for \(s) seconds" }
        return "Thinking"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    if message.thinkingSeconds == nil { DSThinkingDots() }
                    Text(header).font(DS.Font.secondary).foregroundStyle(DS.Palette.textTertiary)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Palette.textTertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            if expanded && !message.thinking.isEmpty {
                Text(message.thinking)
                    .font(DS.Font.secondary).foregroundStyle(DS.Palette.textTertiary)
                    .lineSpacing(4).textSelection(.enabled)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) { Rectangle().fill(DS.Palette.separator).frame(width: 2) }
            }
        }
        .onChange(of: message.thinkingSeconds) { _, s in if s != nil { withAnimation { expanded = false } } }
    }
}

// MARK: - Streaming indicators

private struct DSCaret: View {
    @State private var on = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5).fill(DS.Palette.brand)
            .frame(width: 9, height: 18).opacity(on ? 1 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { on = false } }
    }
}

private struct DSTypingDots: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().fill(DS.Palette.textTertiary).frame(width: 7, height: 7)
                    .opacity(0.3 + 0.7 * abs(sin(phase + Double(i) * 0.6)))
            }
        }
        .onAppear { withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { phase = .pi * 2 } }
    }
}

private struct DSThinkingDots: View {
    @State private var t = 0.0
    var body: some View {
        Circle().fill(DS.Palette.brand).frame(width: 6, height: 6)
            .opacity(0.4 + 0.6 * abs(sin(t)))
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { t = .pi } }
    }
}
