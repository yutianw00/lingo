import Foundation

enum APIError: LocalizedError {
    case signInRequired
    case http(Int, String)
    case badServerURL

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign-in required"
        case let .http(code, body): "HTTP \(code): \(body)"
        case .badServerURL: "Invalid server address"
        }
    }
}

/// Thin client for the FastAPI backend (same endpoints as the web app).
///
/// Every request carries the device's timezone offset (for "today"/streaks) and either
/// the session token (`Authorization: Bearer`, when Google sign-in is on) or the local
/// user id (`X-User-Id`, when the server runs without sign-in).
final class API: @unchecked Sendable {
    static let shared = API()

    /// The deployed backend, used unless told otherwise.
    static let defaultServer = "https://lingo-tiw0.onrender.com"
    /// The backend on this Mac (from the simulator), selected with the `-local` launch flag.
    static let localServer = "http://localhost:8000"
    static let serverKey = "serverURL"

    /// Base URL of the backend, in order of precedence:
    /// launch argument `-serverURL http://…`, launch flag `-local` (→ `localServer`),
    /// the address saved in the app (sign-in screen / settings), then `defaultServer`.
    var server: String {
        get {
            let args = ProcessInfo.processInfo.arguments
            if !args.contains("-serverURL") && args.contains("-local") { return Self.localServer }
            return UserDefaults.standard.string(forKey: Self.serverKey) ?? Self.defaultServer
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.serverKey) }
    }

    /// Session token from Google sign-in, kept in the Keychain.
    var token: String? {
        get { Keychain.get("session") }
        set { if let newValue { Keychain.set(newValue, for: "session") } else { Keychain.delete("session") } }
    }

    let localUserId = "demo"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    func url(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        let base = server.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var c = URLComponents(string: base + "/api" + path), c.scheme != nil, c.host != nil else {
            throw APIError.badServerURL
        }
        if !query.isEmpty { c.queryItems = query }
        guard let u = c.url else { throw APIError.badServerURL }
        return u
    }

    private func send<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = [],
                                    body: (some Encodable)? = Optional<Int>.none) async throws -> T {
        var req = URLRequest(url: try url(path, query: query))
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Same sign as JS Date.getTimezoneOffset(): minutes *behind* UTC (UTC+8 → -480).
        req.setValue(String(-TimeZone.current.secondsFromGMT() / 60), forHTTPHeaderField: "X-Tz-Offset")
        req.setValue(localUserId, forHTTPHeaderField: "X-User-Id")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try encoder.encode(body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.signInRequired }
        guard (200..<300).contains(status) else {
            throw APIError.http(status, String(decoding: data, as: UTF8.self))
        }
        return try decoder.decode(T.self, from: data)
    }

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem] = []) async throws -> T {
        try await send("GET", path, query: query)
    }

    private struct Empty: Encodable {}
    private struct OK: Decodable { var ok: Bool }

    // MARK: endpoints

    func authConfig() async throws -> AuthConfig { try await get("/auth/config") }
    func me() async throws -> Me { try await get("/me") }

    func saveMe(native: Lang, target: Lang) async throws -> Me {
        struct Body: Encodable { var native: Lang; var target: Lang }
        return try await send("PUT", "/me", body: Body(native: native, target: target))
    }

    func home() async throws -> HomeData { try await get("/home") }

    func wordSession(size: Int = 20) async throws -> [WordCard] {
        try await get("/words/session", [URLQueryItem(name: "size", value: String(size))])
    }

    func reviewWord(_ id: String, known: Bool, peeked: Bool, elapsedMs: Int) async throws -> ReviewResult {
        struct Body: Encodable { var known: Bool; var peeked: Bool; var elapsedMs: Int }
        return try await send("POST", "/words/\(escape(id))/review",
                              body: Body(known: known, peeked: peeked, elapsedMs: elapsedMs))
    }

    func undoWord(_ id: String) async throws -> Progress {
        try await send("POST", "/words/\(escape(id))/undo", body: Empty())
    }

    func words() async throws -> [WordCard] { try await get("/words") }

    func quizSession(size: Int = 10) async throws -> [Question] {
        try await get("/quiz/session", [URLQueryItem(name: "size", value: String(size))])
    }

    func answer(_ id: String, choice: String, elapsedMs: Int) async throws -> AnswerResult {
        struct Body: Encodable { var choice: String; var elapsedMs: Int }
        return try await send("POST", "/quiz/\(escape(id))/answer", body: Body(choice: choice, elapsedMs: elapsedMs))
    }

    func questionWords(_ id: String) async throws -> QuestionWords {
        try await get("/quiz/\(escape(id))/words")
    }

    func addWord(_ word: String, meaning: String, pos: String, questionId: String?) async throws -> WordCard {
        struct Body: Encodable { var word: String; var meaning: String; var pos: String; var questionId: String? }
        return try await send("POST", "/words/custom", body: Body(word: word, meaning: meaning, pos: pos, questionId: questionId))
    }

    func removeWord(_ id: String) async throws {
        let _: OK = try await send("DELETE", "/words/custom/\(escape(id))")
    }

    /// Trade the one-time code from `lingo://auth?code=…` (plus our PKCE verifier) for a session token.
    func appToken(code: String, verifier: String) async throws -> String {
        struct Body: Encodable { var code: String; var verifier: String }
        struct Out: Decodable { var token: String }
        let out: Out = try await send("POST", "/auth/app/token", body: Body(code: code, verifier: verifier))
        return out.token
    }

    func logout() async {
        let _: OK? = try? await send("POST", "/auth/logout", body: Empty())
    }

    private func escape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? s
    }
}
