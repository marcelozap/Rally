import Foundation

enum RallyAPIClient {

    private static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private struct CredentialsBody: Codable {
        let email: String
        let password: String
    }

    /// Server's response to a `PUT /api/me/sync`. When `merged` is present,
    /// the server has reconciled the client's envelope against the stored
    /// row using `ProgressPayload.mergedMaxWins`. The client should apply
    /// the merged numerics locally so a single round-trip is enough to
    /// converge.
    ///
    /// `revision` reflects the new server-side row revision. Callers should
    /// persist it and send it as `X-Rally-Expected-Revision` on the next
    /// avatar-only PUT so the server can detect concurrent edits (409).
    struct SyncPutResponse: Codable {
        let ok: Bool?
        let updatedAt: Date?
        let revision: Int?
        let merged: SyncEnvelope?
    }

    /// Error thrown when the server returns 409 (avatar revision conflict).
    struct RevisionConflict: Error {
        let serverRevision: Int
    }

    static func register(email: String, password: String) async throws -> AuthTokenResponse {
        try await postCredentials(path: "api/auth/register", email: email, password: password)
    }

    static func login(email: String, password: String) async throws -> AuthTokenResponse {
        try await postCredentials(path: "api/auth/login", email: email, password: password)
    }

    private static func postCredentials(path: String, email: String, password: String) async throws -> AuthTokenResponse {
        let url = RallyAPIConfig.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try jsonEncoder.encode(CredentialsBody(email: email, password: password))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RallyAPIError.http(-1, nil) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw RallyAPIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = try? jsonDecoder.decode(APIErrorPayload.self, from: data).error
            throw RallyAPIError.http(http.statusCode, msg)
        }
        return try jsonDecoder.decode(AuthTokenResponse.self, from: data)
    }

    static func fetchSync(token: String) async throws -> SyncEnvelope {
        let url = RallyAPIConfig.baseURL.appendingPathComponent("api/me/sync")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RallyAPIError.http(-1, nil) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw RallyAPIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = try? jsonDecoder.decode(APIErrorPayload.self, from: data).error
            throw RallyAPIError.http(http.statusCode, msg)
        }
        return try jsonDecoder.decode(SyncEnvelope.self, from: data)
    }

    @discardableResult
    static func putSync(
        token: String,
        envelope: SyncEnvelope,
        expectedRevision: Int? = nil
    ) async throws -> SyncPutResponse {
        let url = RallyAPIConfig.baseURL.appendingPathComponent("api/me/sync")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let rev = expectedRevision {
            req.setValue(String(rev), forHTTPHeaderField: "X-Rally-Expected-Revision")
        }
        req.httpBody = try jsonEncoder.encode(envelope)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RallyAPIError.http(-1, nil) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw RallyAPIError.unauthorized
        }
        if http.statusCode == 409 {
            // Parse the server revision from the header (preferred) or body.
            let serverRevision: Int
            if let headerVal = http.value(forHTTPHeaderField: "X-Rally-Current-Revision"),
               let parsed = Int(headerVal) {
                serverRevision = parsed
            } else if let body = try? jsonDecoder.decode([String: Int].self, from: data),
                      let sr = body["serverRevision"] {
                serverRevision = sr
            } else {
                serverRevision = 0
            }
            throw RevisionConflict(serverRevision: serverRevision)
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = try? jsonDecoder.decode(APIErrorPayload.self, from: data).error
            throw RallyAPIError.http(http.statusCode, msg)
        }
        return try jsonDecoder.decode(SyncPutResponse.self, from: data)
    }
}
