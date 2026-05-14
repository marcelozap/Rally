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
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

                        fieldLabel("Password")
                        SecureField(mode == .register ? "At least 8 characters" : "Password", text: $password)
                            .textContentType(mode == .register ? .newPassword : .password)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                    .foregroundStyle(.white)

                    if let err = auth.lastErrorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if busy { ProgressView().tint(.black) }
                            Text(mode == .register ? "Create account" : "Log in")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cyan))
                        .foregroundStyle(.black)
                    }
                    .disabled(busy || !canSubmit)

                    DisclosureGroup(isExpanded: $devOpen) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API base URL (simulator default: http://127.0.0.1:8787)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                            TextField("http://…", text: $apiBaseURL)
                                .autocapitalization(.none)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                                .foregroundStyle(.white)
                            Button("Use simulator default") {
                                RallyAPIConfig.setBaseURL(nil)
                                apiBaseURL = RallyAPIConfig.baseURL.absoluteString
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("Developer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .tint(.cyan)

                    Text("Your avatar, progression, logs and journal sync to your account after login.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .padding(24)
            }
            .background(Color.black.ignoresSafeArea())
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
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)
            Text("Save your player everywhere")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Create an account to back up your avatar and stats.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
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
