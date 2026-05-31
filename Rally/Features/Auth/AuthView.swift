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

                    modeRail

                    RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
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
                    }

                    if let err = auth.lastErrorMessage {
                        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.coral.opacity(0.32)) {
                            HStack(alignment: .top, spacing: 12) {
                                RallyUIKit.IconBadge(systemName: "exclamationmark.triangle.fill", tint: RallyUIKit.Palette.coral, size: 28)
                                Text(err)
                                    .font(RallyUIKit.Typography.body(.caption))
                                    .foregroundStyle(RallyUIKit.Palette.cloud)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
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

                    #if DEBUG
                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line.opacity(0.7)) {
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.sm) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    devOpen.toggle()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Developer")
                                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                                            .foregroundStyle(RallyUIKit.Palette.cloud)
                                        Text("Local API routing for simulator and device testing.")
                                            .font(RallyUIKit.Typography.body(.caption))
                                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                                    }
                                    Spacer()
                                    Image(systemName: devOpen ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RallyUIKit.Palette.cyan)
                                }
                            }
                            .buttonStyle(.plain)

                            if devOpen {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("API base URL (simulator default: http://127.0.0.1:8787)")
                                        .font(RallyUIKit.Typography.body(.caption))
                                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                                    TextField("http://…", text: $apiBaseURL)
                                        .autocapitalization(.none)
                                        .rallyTextFieldStyle()
                                    Button("Use simulator default") {
                                        RallyAPIConfig.setBaseURL(nil)
                                        apiBaseURL = RallyAPIConfig.baseURL.absoluteString
                                    }
                                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.cyan)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                    #endif

                    Text(
                        "Signed-in accounts back up avatar, progression, training, matches, and journal to the Rally API. "
                            + "Your latest saved session becomes the one Rally keeps in sync. "
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
            #if DEBUG
            if apiBaseURL.isEmpty {
                apiBaseURL = RallyAPIConfig.baseURL.absoluteString
            }
            #endif
        }
    }

    private var modeRail: some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line.opacity(0.7)) {
            HStack(spacing: RallyUIKit.Spacing.xs) {
                ForEach(Mode.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            mode = option
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.rawValue)
                                .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                                .foregroundStyle(mode == option ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
                            Text(option == .login ? "Return to your player" : "Start syncing your game")
                                .font(RallyUIKit.Typography.body(.caption))
                                .foregroundStyle(mode == option ? RallyUIKit.Palette.obsidian.opacity(0.72) : RallyUIKit.Palette.cloud.opacity(0.62))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, RallyUIKit.Spacing.md)
                        .padding(.vertical, RallyUIKit.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md, style: .continuous)
                                .fill(mode == option ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)) : AnyShapeStyle(Color.white.opacity(0.04)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md, style: .continuous)
                                .stroke(mode == option ? Color.white.opacity(0.18) : RallyUIKit.Palette.line.opacity(0.7), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
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
        #if DEBUG
        RallyAPIConfig.setBaseURL(apiBaseURL)
        #endif

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
