import Foundation
import SwiftData

@MainActor
final class AuthSession: ObservableObject {

    /// Finished validating stored JWT on cold launch (or determined there is none).
    @Published private(set) var isBootstrapped = false

    @Published private(set) var isAuthenticated = false

    /// Local-only mode (`Continue offline`); see `ARCHITECTURE.md`.
    @Published private(set) var isGuestMode = false

    @Published private(set) var userEmail: String?

    @Published var lastErrorMessage: String?

    /// Signed-in account **or** guest session — either may enter `ContentView`.
    var hasEnteredApp: Bool {
        isAuthenticated || isGuestMode
    }

    func bootstrap(modelContext: ModelContext) async {
        defer { isBootstrapped = true }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-RallyAutoPlay") {
            isGuestMode = true
            isAuthenticated = false
            return
        }
        #endif

        if KeychainStore.shared.token != nil {
            do {
                try await RallySyncCoordinator.pull(modelContext: modelContext)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.guestMode)
                isGuestMode = false
                isAuthenticated = true
                userEmail = UserDefaults.standard.string(forKey: UserDefaultsKeys.savedEmail)
                return
            } catch {
                KeychainStore.shared.clearToken()
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.savedEmail)
            }
        }

        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.guestMode) {
            isGuestMode = true
            isAuthenticated = false
            userEmail = nil
            return
        }

        isGuestMode = false
        isAuthenticated = false
        userEmail = UserDefaults.standard.string(forKey: UserDefaultsKeys.savedEmail)
    }

    func enterGuestMode() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.guestMode)
        isGuestMode = true
        isAuthenticated = false
        userEmail = nil
        lastErrorMessage = nil
    }

    func register(email: String, password: String, modelContext: ModelContext) async throws {
        lastErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.guestMode)
        isGuestMode = false
        let res = try await RallyAPIClient.register(email: email, password: password)
        persistLogin(res)
        try await RallySyncCoordinator.pull(modelContext: modelContext)
        isAuthenticated = true
    }

    func login(email: String, password: String, modelContext: ModelContext) async throws {
        lastErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.guestMode)
        isGuestMode = false
        let res = try await RallyAPIClient.login(email: email, password: password)
        persistLogin(res)
        try await RallySyncCoordinator.pull(modelContext: modelContext)
        isAuthenticated = true
    }

    func logout() {
        KeychainStore.shared.clearToken()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.savedEmail)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.guestMode)
        isAuthenticated = false
        isGuestMode = false
        userEmail = nil
        lastErrorMessage = nil
    }

    func mapAPIError(_ error: Error) -> String {
        switch error {
        case RallyAPIError.unauthorized:
            return "Could not sign you in. Check your email and password."
        case RallyAPIError.invalidURL:
            return "Invalid API URL. Fix it under Developer options."
        case RallyAPIError.decoding:
            return "Could not read server data."
        case RallyAPIError.http(let code, let msg):
            if let msg, !msg.isEmpty { return msg }
            return "Server error (\(code))."
        default:
            break
        }

        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet:
                return "No internet connection."
            case .cannotFindHost, .cannotConnectToHost, .timedOut:
                return "Cannot reach the Rally API. Start the backend or check the URL in Developer."
            default:
                return urlErr.localizedDescription
            }
        }

        return error.localizedDescription
    }

    private func persistLogin(_ res: AuthTokenResponse) {
        KeychainStore.shared.token = res.token
        UserDefaults.standard.set(res.user.email, forKey: UserDefaultsKeys.savedEmail)
        userEmail = res.user.email
    }
}
