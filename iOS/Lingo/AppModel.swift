import Foundation
import Observation

/// App-wide state: who is signed in, and their settings.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case loading
        case unreachable(String)
        case signedOut(error: String?)
        case ready(Me)
    }

    var phase: Phase = .loading
    var signingIn = false

    var me: Me? {
        if case let .ready(m) = phase { return m }
        return nil
    }

    /// UI strings follow the learner's native language (device language before sign-in).
    var t: Strings { Strings.for(me?.native ?? .device) }

    func load() async {
        phase = .loading
        do {
            phase = .ready(try await API.shared.me())
        } catch APIError.signInRequired {
            API.shared.token = nil
            phase = .signedOut(error: nil)
        } catch {
            phase = .unreachable(error.localizedDescription)
        }
    }

    func signIn() async {
        signingIn = true
        defer { signingIn = false }
        do {
            API.shared.token = try await GoogleSignIn().signIn()
            await load()
        } catch GoogleSignIn.Failure.cancelled {
            phase = .signedOut(error: nil)
        } catch {
            phase = .signedOut(error: "failed")
        }
    }

    func signOut() async {
        await API.shared.logout()
        API.shared.token = nil
        await load()
    }

    func update(_ me: Me) { phase = .ready(me) }

    /// Any API call that fails with 401 sends the user back to sign-in. The "expired" notice only
    /// shows when the session ended under a signed-in user — not for a screen that was still
    /// loading while the user signed out on purpose.
    func handle(_ error: Error) -> Bool {
        guard case APIError.signInRequired = error else { return false }
        API.shared.token = nil
        if case .ready = phase { phase = .signedOut(error: "state") }
        return true
    }
}
