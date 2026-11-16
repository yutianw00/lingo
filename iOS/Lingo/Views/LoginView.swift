import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model
    let error: String?
    @State private var showServer = false
    @State private var server = API.shared.server

    var body: some View {
        let t = model.t
        VStack(spacing: 0) {
            Spacer()
            Text("🃏").font(.system(size: 72))
            Text("Lingo").font(.system(size: 34, weight: .heavy)).padding(.top, 8)
            Text(t.signInSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Spacer()
            if let error {
                Text(t.signInError[error] ?? t.signInError["failed"]!)
                    .font(.system(size: 14)).foregroundStyle(Theme.bad).padding(.bottom, 12)
            }
            Button {
                Task { await model.signIn() }
            } label: {
                HStack(spacing: 10) {
                    GoogleLogo().frame(width: 20, height: 20)
                    Text(t.signInGoogle)
                }
            }
            .buttonStyle(.chunky(.ghost))
            .disabled(model.signingIn)

            if showServer {
                ServerField(server: $server)
                    .padding(.top, 12)
                    .onSubmit { API.shared.server = server }
                    .onChange(of: server) { API.shared.server = server }
            }
            Button {
                withAnimation { showServer.toggle() }
            } label: {
                Text("\(t.server): \(API.shared.server)")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(.top, 12)
        }
        .padding(24)
        .background(Theme.bg)
    }
}

/// The four-color "G", drawn from the same paths as the web button.
struct GoogleLogo: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 48, y: size.height / 48)
            func p(_ build: (inout Path) -> Void) -> Path { var path = Path(); build(&path); return path }
            ctx.fill(p { $0.move(to: .init(x: 24, y: 9.5)); $0.addCurve(to: .init(x: 33, y: 13.1), control1: .init(x: 27.5, y: 9.5), control2: .init(x: 30.6, y: 10.7)); $0.addLine(to: .init(x: 39.7, y: 6.4)); $0.addCurve(to: .init(x: 24, y: 0), control1: .init(x: 35.6, y: 2.4), control2: .init(x: 30.2, y: 0)); $0.addCurve(to: .init(x: 2.6, y: 13.3), control1: .init(x: 14.6, y: 0), control2: .init(x: 6.6, y: 5.4)); $0.addLine(to: .init(x: 10.4, y: 19.3)); $0.addCurve(to: .init(x: 24, y: 9.5), control1: .init(x: 12.3, y: 13.5), control2: .init(x: 17.7, y: 9.5)) }, with: .color(Color(UIColor(hex: 0xEA4335))))
            ctx.fill(p { $0.move(to: .init(x: 46.1, y: 24.5)); $0.addCurve(to: .init(x: 45.7, y: 20), control1: .init(x: 46.1, y: 22.9), control2: .init(x: 46, y: 21.4)); $0.addLine(to: .init(x: 24, y: 20)); $0.addLine(to: .init(x: 24, y: 29)); $0.addLine(to: .init(x: 36.4, y: 29)); $0.addCurve(to: .init(x: 31.8, y: 35.9), control1: .init(x: 35.9, y: 31.9), control2: .init(x: 34.2, y: 34.3)); $0.addLine(to: .init(x: 39.2, y: 41.7)); $0.addCurve(to: .init(x: 46.1, y: 24.5), control1: .init(x: 43.5, y: 37.7), control2: .init(x: 46.1, y: 31.8)) }, with: .color(Color(UIColor(hex: 0x4285F4))))
            ctx.fill(p { $0.move(to: .init(x: 10.4, y: 28.7)); $0.addCurve(to: .init(x: 9.6, y: 24), control1: .init(x: 9.9, y: 27.3), control2: .init(x: 9.6, y: 25.7)); $0.addCurve(to: .init(x: 10.4, y: 19.3), control1: .init(x: 9.6, y: 22.3), control2: .init(x: 9.9, y: 20.8)); $0.addLine(to: .init(x: 2.6, y: 13.3)); $0.addCurve(to: .init(x: 0, y: 24), control1: .init(x: 0.9, y: 16.6), control2: .init(x: 0, y: 20.2)); $0.addCurve(to: .init(x: 2.6, y: 34.7), control1: .init(x: 0, y: 27.8), control2: .init(x: 0.9, y: 31.4)); $0.addLine(to: .init(x: 10.4, y: 28.7)) }, with: .color(Color(UIColor(hex: 0xFBBC05))))
            ctx.fill(p { $0.move(to: .init(x: 24, y: 48)); $0.addCurve(to: .init(x: 39.9, y: 42.2), control1: .init(x: 30.5, y: 48), control2: .init(x: 35.9, y: 45.9)); $0.addLine(to: .init(x: 32.5, y: 36.4)); $0.addCurve(to: .init(x: 24, y: 38.7), control1: .init(x: 30.4, y: 37.8), control2: .init(x: 27.7, y: 38.7)); $0.addCurve(to: .init(x: 10.4, y: 29.1), control1: .init(x: 17.7, y: 38.7), control2: .init(x: 12.3, y: 34.7)); $0.addLine(to: .init(x: 2.6, y: 35.1)); $0.addCurve(to: .init(x: 24, y: 48), control1: .init(x: 6.6, y: 42.6), control2: .init(x: 14.6, y: 48)) }, with: .color(Color(UIColor(hex: 0x34A853))))
        }
    }
}

#if DEBUG
#Preview("Sign in") {
    LoginView(error: nil).environment(AppModel.preview(.signedOut(error: nil)))
}

#Preview("Sign in failed") {
    LoginView(error: "failed").environment(AppModel.preview(.signedOut(error: "failed")))
}
#endif
