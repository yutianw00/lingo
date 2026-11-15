import SwiftUI

struct LangBadge: View {
    let lang: Lang
    var size: CGFloat = 32

    var body: some View {
        Text(lang.rawValue.uppercased())
            .font(.system(size: size * 0.38, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.lang(lang), in: Circle())
    }
}

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(Theme.good).frame(width: g.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 14)
        .animation(.easeOut(duration: 0.35), value: value)
    }
}

struct LevelBars: View {
    let level: Level
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { k in
                RoundedRectangle(cornerRadius: 3)
                    .fill(k < level.bars ? Theme.level(level) : Theme.line)
                    .frame(width: 6, height: 14)
            }
        }
    }
}

struct GenderBadge: View {
    let gender: Gender
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 7).padding(.vertical, 1)
            .foregroundStyle(Theme.gender(gender))
            .background(Theme.gender(gender).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct LvTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .padding(.horizontal, 7).padding(.vertical, 1)
            .foregroundStyle(Theme.primary)
            .background(Theme.soft, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct Tag: View {
    let text: String
    let fg: Color
    let bg: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}

/// The chunky "3D" button from the web app.
struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case primary, good, bad, ghost }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let (fill, shadow, text): (Color, Color, Color) = {
            if !enabled { return (Theme.line, Theme.lineDark, Theme.muted) }
            switch kind {
            case .primary: return (Theme.primary, Theme.primaryDark, .white)
            case .good: return (Theme.good, Theme.goodDark, .white)
            case .bad: return (Theme.bad, Theme.badDark, .white)
            case .ghost: return (Theme.card, Theme.line, Theme.ink)
            }
        }()
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(fill))
            .overlay {
                if kind == .ghost { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line, lineWidth: 2) }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(shadow).offset(y: pressed ? 2 : 4))
            .offset(y: pressed ? 2 : 0)
            .padding(.bottom, 4)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }
    static func chunky(_ kind: ChunkyButtonStyle.Kind) -> ChunkyButtonStyle { ChunkyButtonStyle(kind: kind) }
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.line, lineWidth: 2))
    }
}

struct SectionTitle: View {
    let text: String
    var detail: String?
    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(.system(size: 17, weight: .heavy))
            if let detail { Text(detail).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20).padding(.bottom, 10)
    }
}

/// Full-screen message with an optional action, used for loading / error / empty states.
struct Message: View {
    let text: String
    var detail: String?
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text(text).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            if let detail { Text(detail).font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center) }
            if let action {
                Button(action.title, action: action.run).buttonStyle(.chunky).frame(maxWidth: 240)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

/// Small toast at the top of the screen.
@MainActor
@Observable
final class Toaster {
    var text: String?
    private var task: Task<Void, Never>?

    func show(_ s: String) {
        text = s
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { text = nil }
        }
    }
}

struct ToastView: View {
    let text: String?
    var body: some View {
        VStack {
            if let text {
                Text(text)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 56)
        .animation(.easeOut(duration: 0.25), value: text)
        .allowsHitTesting(false)
    }
}

struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.muted)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("Close")
    }
}

extension String {
    /// `Text(verbatim:)` safe for user content (no Markdown / localization lookups).
    var plain: Text { Text(verbatim: self) }
}
