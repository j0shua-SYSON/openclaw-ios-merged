import SwiftUI

// MARK: - Sign-in

struct DSAuthView: View {
    @ObservedObject var model: DeepSeekChatModel
    @State private var showPassword = false
    @State private var consent = false

    private let terms = "https://cdn.deepseek.com/policies/en-US/deepseek-terms-of-use.html"
    private let privacy = "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 40)
                Image("DSWhale", bundle: .deepSeek).resizable().scaledToFit().frame(height: 60)
                Text("deepseek").font(.system(size: 28, weight: .semibold)).foregroundStyle(DS.Palette.textPrimary)
                Text("Log in with your DeepSeek account (email + password).")
                    .font(DS.Font.secondary).foregroundStyle(DS.Palette.textTertiary)
                    .multilineTextAlignment(.center).padding(.horizontal, 30).padding(.bottom, 6)

                field(icon: "envelope", placeholder: "Email / +86 phone number", text: $model.email,
                      secure: false, keyboard: .emailAddress)
                passwordField

                if let err = model.errorText {
                    Text(err).font(DS.Font.caption).foregroundStyle(DS.Palette.error)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                }

                consentRow

                Button(action: attemptSignIn) {
                    HStack(spacing: 8) {
                        if model.signingIn { ProgressView().tint(.white) }
                        Text(model.signingIn ? "Logging in…" : "Log in").font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(DS.Palette.brandHeadline, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                }
                .disabled(model.signingIn)

                HStack {
                    Text("Forgot password?").font(DS.Font.secondary).foregroundStyle(DS.Palette.brandText)
                    Spacer()
                    Text("Sign up").font(DS.Font.secondary).foregroundStyle(DS.Palette.brandText)
                }
                .padding(.horizontal, 4).padding(.top, 2)

                orDivider

                socialButton(title: "Continue with Apple", system: "apple.logo")
                socialButton(title: "Continue with Google", system: "g.circle")

                Button("Continue as guest") { model.continueAsGuest() }
                    .font(DS.Font.caption).foregroundStyle(DS.Palette.textTertiary).padding(.top, 4)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func attemptSignIn() {
        guard consent else { model.errorText = "Please agree to the Terms of Use and Privacy Policy."; return }
        model.signIn()
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, secure: Bool, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(DS.Palette.textTertiary).frame(width: 20)
            TextField(placeholder, text: text)
                .keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(DS.Font.body).foregroundStyle(DS.Palette.textPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 12).stroke(DS.Palette.inputBorder, lineWidth: 1))
    }

    private var passwordField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock").font(.system(size: 16)).foregroundStyle(DS.Palette.textTertiary).frame(width: 20)
            Group {
                if showPassword { TextField("Password", text: $model.password) }
                else { SecureField("Password", text: $model.password) }
            }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .font(DS.Font.body).foregroundStyle(DS.Palette.textPrimary)
            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye").font(.system(size: 15)).foregroundStyle(DS.Palette.textTertiary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 12).stroke(DS.Palette.inputBorder, lineWidth: 1))
    }

    private var consentRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { consent.toggle() } label: {
                Image(systemName: consent ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18)).foregroundStyle(consent ? DS.Palette.brand : DS.Palette.textTertiary)
            }.buttonStyle(.plain)
            Text(.init("I confirm that I have read and agree to DeepSeek's [Terms of Use](\(terms)) and [Privacy Policy](\(privacy))."))
                .font(DS.Font.caption).foregroundStyle(DS.Palette.textSecondary).tint(DS.Palette.brandText)
        }
        .padding(.horizontal, 4)
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(DS.Palette.separator).frame(height: 1)
            Text("or").font(DS.Font.caption).foregroundStyle(DS.Palette.textTertiary)
            Rectangle().fill(DS.Palette.separator).frame(height: 1)
        }.padding(.vertical, 2)
    }

    private func socialButton(title: String, system: String) -> some View {
        Button { model.errorText = "This build supports email sign-in. Use your DeepSeek email + password." } label: {
            HStack(spacing: 8) {
                Image(systemName: system).font(.system(size: 16))
                Text(title).font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(DS.Palette.textPrimary)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).stroke(DS.Palette.inputBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History drawer

struct DSDrawerOverlay: View {
    @ObservedObject var model: DeepSeekChatModel

    var body: some View {
        ZStack(alignment: .leading) {
            if model.drawerOpen {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { model.drawerOpen = false } }
                    .transition(.opacity)
                DSDrawer(model: model)
                    .frame(width: UIScreen.main.bounds.width * 0.84)
                    .frame(maxHeight: .infinity)
                    .background(DS.Palette.bg)
                    .transition(.move(edge: .leading))
            }
        }
    }
}

private struct DSDrawer: View {
    @ObservedObject var model: DeepSeekChatModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { model.newChat() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil").font(.system(size: 16, weight: .semibold))
                    Text("New chat").font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(DS.Palette.brand)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(DS.Palette.toggleActiveFill, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.top, 12)

            if model.chatStarted {
                Text("Today").font(DS.Font.caption).foregroundStyle(DS.Palette.textTertiary)
                    .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 6)
                Button { withAnimation(.easeOut(duration: 0.25)) { model.drawerOpen = false } } label: {
                    HStack {
                        Text(model.chatTitle).font(DS.Font.body).foregroundStyle(DS.Palette.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 11).padding(.horizontal, 14)
                    .background(DS.Palette.layer2, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain).padding(.horizontal, 14)
            } else {
                VStack(spacing: 6) {
                    Text("No chat yet").font(DS.Font.body).foregroundStyle(DS.Palette.textSecondary)
                    Text("Your chat with DeepSeek will be displayed here.")
                        .font(DS.Font.caption).foregroundStyle(DS.Palette.textTertiary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal, 20)
            }

            Spacer()
            Divider().overlay(DS.Palette.separator)
            HStack(spacing: 12) {
                Circle().fill(DS.Palette.toggleActiveFill).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "person.fill").font(.system(size: 15)).foregroundStyle(DS.Palette.brand))
                Text(model.accountLabel).font(DS.Font.secondary).foregroundStyle(DS.Palette.textPrimary).lineLimit(1)
                Spacer()
                Button { model.logout() } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 16))
                        .foregroundStyle(DS.Palette.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .padding(.top, 44)
        .ignoresSafeArea(edges: .bottom)
    }
}
