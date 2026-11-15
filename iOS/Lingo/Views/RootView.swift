import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                Message(text: model.t.loading)
            case let .unreachable(detail):
                UnreachableView(detail: detail)
            case let .signedOut(error):
                LoginView(error: error)
            case let .ready(me):
                if me.onboarded { MainTabs() } else { SetupView(firstRun: true) }
            }
        }
        .tint(Theme.primary)
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @State private var tab = DebugLaunch.screen == "words" ? 1 : 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label(model.t.tabLearn, systemImage: "house.fill") }
                .tag(0)
            WordsView()
                .tabItem { Label(model.t.tabWords, systemImage: "books.vertical.fill") }
                .tag(1)
        }
    }
}

/// Shown when the backend can't be reached: lets you fix the server address and retry.
struct UnreachableView: View {
    @Environment(AppModel.self) private var model
    let detail: String
    @State private var server = API.shared.server

    var body: some View {
        let t = model.t
        VStack(spacing: 16) {
            Spacer()
            Text("⚠️").font(.system(size: 48))
            Text(t.error).font(.headline).multilineTextAlignment(.center)
            Text(detail).font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            ServerField(server: $server)
            Button(t.retry) {
                API.shared.server = server
                Task { await model.load() }
            }
            .buttonStyle(.chunky)
            Spacer()
            Text("cd backend && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(24)
        .background(Theme.bg)
    }
}

struct ServerField: View {
    @Environment(AppModel.self) private var model
    @Binding var server: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t.server).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
            TextField(API.defaultServer, text: $server)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 2))
        }
    }
}

/// Debug-only launch arguments for jumping straight to a screen (`-screen swipe|quiz|words|setup`).
enum DebugLaunch {
    static var screen: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "screen")
        #else
        nil
        #endif
    }
}
