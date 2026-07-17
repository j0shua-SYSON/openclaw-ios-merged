import SwiftUI

// MARK: - Model

struct DSMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

// MARK: - View model

@MainActor
final class DeepSeekChatModel: ObservableObject {
    enum Screen { case auth, chat }

    @Published var screen: Screen
    @Published var messages: [DSMessage] = []
    @Published var input: String = ""
    @Published var isStreaming = false
    @Published var errorText: String?

    // Auth screen state
    @Published var email = ""
    @Published var password = ""
    @Published var signingIn = false

    private var token: String? { didSet { persistToken() } }
    private var isGuest = false
    private var sessionId: String?
    private var parentMessageID: Int?
    private let api = DeepSeekAPI.shared

    init() {
        let saved = UserDefaults.standard.string(forKey: "deepseek.token")
        self.token = saved
        self.email = UserDefaults.standard.string(forKey: "deepseek.email") ?? ""
        self.screen = (saved?.isEmpty == false) ? .chat : .auth
    }

    private func persistToken() {
        UserDefaults.standard.set(token, forKey: "deepseek.token")
        UserDefaults.standard.set(email, forKey: "deepseek.email")
    }

    func signIn() {
        errorText = nil
        let e = email.trimmingCharacters(in: .whitespaces)
        let p = password
        guard !e.isEmpty, !p.isEmpty else { errorText = "Enter your DeepSeek email and password."; return }
        signingIn = true
        Task {
            do {
                let t = try await api.login(email: e, password: p)
                self.token = t
                self.isGuest = false
                self.password = ""
                self.resetConversation()
                self.screen = .chat
            } catch {
                self.errorText = (error as? LocalizedError)?.errorDescription ?? "Sign-in failed."
            }
            self.signingIn = false
        }
    }

    func continueAsGuest() {
        errorText = nil
        isGuest = true
        token = nil
        resetConversation()
        screen = .chat
    }

    func logout() {
        token = nil
        isGuest = false
        sessionId = nil
        parentMessageID = nil
        messages = []
        screen = .auth
    }

    private func resetConversation() {
        messages = []
        sessionId = nil
        parentMessageID = nil
    }

    func send() {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }
        input = ""
        errorText = nil
        messages.append(DSMessage(role: .user, text: prompt))
        let assistantIndex = messages.count
        messages.append(DSMessage(role: .assistant, text: ""))
        isStreaming = true

        Task {
            do {
                let stream: AsyncThrowingStream<String, Error>
                if isGuest {
                    stream = api.streamGuest(prompt: prompt) { [weak self] mid in
                        Task { @MainActor in self?.parentMessageID = mid }
                    }
                } else {
                    guard let token else { throw DeepSeekError(message: "Signed out — please sign in again.") }
                    if sessionId == nil { sessionId = try await api.createSession(token: token) }
                    stream = api.streamAuthed(token: token, sessionId: sessionId!,
                                              parentMessageID: parentMessageID, prompt: prompt) { [weak self] mid in
                        Task { @MainActor in self?.parentMessageID = mid }
                    }
                }
                for try await fragment in stream {
                    if assistantIndex < messages.count { messages[assistantIndex].text += fragment }
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
                if assistantIndex < messages.count, messages[assistantIndex].text.isEmpty {
                    messages.remove(at: assistantIndex)
                }
                errorText = msg
            }
            isStreaming = false
        }
    }
}

// MARK: - Root

struct DeepSeekRootView: View {
    @StateObject private var model = DeepSeekChatModel()

    var body: some View {
        Group {
            switch model.screen {
            case .auth: DeepSeekAuthView(model: model)
            case .chat: DeepSeekChatView(model: model)
            }
        }
    }
}

// MARK: - Auth

private struct DeepSeekAuthView: View {
    @ObservedObject var model: DeepSeekChatModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "brain")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)
                Text("DeepSeek")
                    .font(.system(size: 30, weight: .bold))
                Text("Sign in with your DeepSeek account to chat. Guest mode works only where DeepSeek enables it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    TextField("Email", text: $model.email)
                        .textContentType(.username).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $model.password)
                        .textContentType(.password)
                }
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

                if let err = model.errorText {
                    Text(err).font(.footnote).foregroundStyle(.red)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }

                Button(action: model.signIn) {
                    HStack {
                        if model.signingIn { ProgressView().tint(.white) }
                        Text(model.signingIn ? "Signing in…" : "Sign in").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(.tint, in: Capsule()).foregroundStyle(.white)
                }
                .disabled(model.signingIn)
                .padding(.horizontal, 24)

                Button("Continue as guest", action: model.continueAsGuest)
                    .font(.subheadline)
                    .disabled(model.signingIn)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Chat

private struct DeepSeekChatView: View {
    @ObservedObject var model: DeepSeekChatModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.messages.isEmpty {
                            Text("Ask DeepSeek anything.")
                                .font(.title3).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 60)
                        }
                        ForEach(model.messages) { bubble($0) }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .onChange(of: model.messages.last?.text) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            if let err = model.errorText {
                Text(err).font(.footnote).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }

            HStack(spacing: 10) {
                TextField("Message DeepSeek…", text: $model.input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .onSubmit(model.send)
                Button(action: model.send) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                }
                .disabled(model.input.trimmingCharacters(in: .whitespaces).isEmpty || model.isStreaming)
            }
            .padding(10)
            .background(.bar)
        }
        .navigationTitle("DeepSeek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive, action: model.logout) { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    @ViewBuilder private func bubble(_ m: DSMessage) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text.isEmpty && m.role == .assistant ? "…" : m.text)
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    m.role == .user ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .foregroundStyle(m.role == .user ? .white : .primary)
            if m.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
