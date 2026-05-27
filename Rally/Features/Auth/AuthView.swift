import SwiftUI
import SwiftData

/// Entry gates cloud-backed login before `ContentView` / avatar onboarding.
struct AuthView: View {
    @EnvironmentObject private var auth: AuthSession
    @Environment(\.modelContext) private var modelContext

    private enum Mode: String, CaseIterable, Identifiable {
        case login = "Log in"
        case register = "Create account"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var devOpen = false
    @State private var apiBaseURL = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("Email")
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .rallyTextFieldStyle()

                        fieldLabel("Password")
                        SecureField(mode == .register ? "At least 8 characters" : "Password", text: $password)
                            .textContentType(mode == .register ? .newPassword : .password)
                            .rallyTextFieldStyle()
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    if let err = auth.lastErrorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(RallyUIKit.Palette.coral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 10) {
                            RallyUIKit.IconBadge(
                                systemName: mode == .register ? "person.crop.circle.badge.plus" : "person.crop.circle.badge.checkmark",
                                tint: RallyUIKit.Palette.ink,
                                size: 30
                            )
                            if busy { ProgressView().tint(.black) }
                            Text(mode == .register ? "Create account" : "Log in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                    .disabled(busy || !canSubmit)

                    Button {
                        auth.enterGuestMode()
                    } label: {
                        Label("Continue offline", systemImage: "wifi.slash")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(busy)

                    DisclosureGroup(isExpanded: $devOpen) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API base URL (simulator default: http://127.0.0.1:8787)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                            TextField("http://…", text: $apiBaseURL)
                                .autocapitalization(.none)
                                .rallyTextFieldStyle()
                            Button("Use simulator default") {
                                RallyAPIConfig.setBaseURL(nil)
                                apiBaseURL = RallyAPIConfig.baseURL.absoluteString
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RallyUIKit.Palette.cyan)
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("Developer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .tint(.cyan)

                    Text(
                        "Signed-in accounts back up avatar, progression, training, matches, and journal to the Rally API. "
                            + "Cloud saves use last-writer-wins snapshots — sign in on one device at a time when testing. "
                            + "Offline mode keeps everything on this phone only until you create an account."
                    )
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .padding(24)
            }
            .background(RallyUIKit.screenBackground)
            .navigationTitle("Rally")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if apiBaseURL.isEmpty {
                apiBaseURL = RallyAPIConfig.baseURL.absoluteString
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            RallyUIKit.IconBadge(
                systemName: "person.crop.circle.badge.checkmark",
                tint: RallyUIKit.Palette.cyan,
                size: 66
            )
            Text("Save your player everywhere")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Sign in for cloud backup, or continue offline on this device.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.45))
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() async {
        auth.lastErrorMessage = nil
        busy = true
        defer { busy = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        RallyAPIConfig.setBaseURL(apiBaseURL)

        do {
            switch mode {
            case .register:
                try await auth.register(email: trimmedEmail, password: password, modelContext: modelContext)
            case .login:
                try await auth.login(email: trimmedEmail, password: password, modelContext: modelContext)
            }
        } catch {
            auth.lastErrorMessage = auth.mapAPIError(error)
        }
    }
}
