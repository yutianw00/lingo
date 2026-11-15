import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// Google sign-in for the app, via the backend.
///
/// The backend runs the Google OpenID Connect flow in a system browser sheet
/// (ASWebAuthenticationSession) and finishes by redirecting to `lingo://auth?code=…`.
/// The code is single-use and only redeemable with the PKCE verifier generated here,
/// so the session token itself never travels through a URL.
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Failure: Error { case cancelled, server(String) }

    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> String {
        let verifier = Self.randomVerifier()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let loginURL = try API.shared.url("/auth/google/login", query: [
            URLQueryItem(name: "app_challenge", value: challenge),
            URLQueryItem(name: "claim", value: API.shared.localUserId),
        ])

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: "lingo") { url, error in
                if let url { cont.resume(returning: url) }
                else if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin {
                    cont.resume(throwing: Failure.cancelled)
                } else { cont.resume(throwing: error ?? Failure.server("failed")) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false  // remember the Google account between sign-ins
            session = s
            s.start()
        }
        session = nil

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let err = items.first(where: { $0.name == "error" })?.value {
            throw err == "cancelled" ? Failure.cancelled : Failure.server(err)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else { throw Failure.server("failed") }
        return try await API.shared.appToken(code: code, verifier: verifier)
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Minimal Keychain wrapper for the session token.
enum Keychain {
    private static let service = "lingo"

    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    static func get(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for key: String) {
        delete(key)
        var q = query(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
