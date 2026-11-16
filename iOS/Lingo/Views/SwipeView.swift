import SwiftUI

/// Word swipe: right = know it, left = don't, tap = reveal the meaning, ↶ = undo.
struct SwipeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goQuiz: () -> Void

    @State private var cards: [WordCard]?
    @State private var failed = false
    @State private var i = 0
    @State private var revealed = false
    @State private var drag: CGSize = .zero
    @State private var leaving: CGFloat = 0  // -1 / 1 while the top card flies off
    @State private var history: [(idx: Int, known: Bool)] = []
    @State private var busy = false
    @State private var shownAt = Date()
    @State private var toast = Toaster()

    private let threshold: CGFloat = 110

    var body: some View {
        let t = model.t
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let cards {
                content(cards, t)
            } else if failed {
                Message(text: t.error, action: (t.retry, { Task { await load() } }))
            } else {
                Message(text: t.loading)
            }
            ToastView(text: toast.text)
        }
        .task { await load() }
    }

    private func load() async {
        cards = nil
        failed = false
        do {
            cards = try await API.shared.wordSession(size: 20)
            i = 0
            history = []
            resetCard()
        } catch {
            if model.handle(error) { dismiss() } else { failed = true }
        }
    }

    private func resetCard() {
        revealed = false
        drag = .zero
        shownAt = Date()
    }

    @ViewBuilder
    private func content(_ cards: [WordCard], _ t: Strings) -> some View {
        let finished = i >= cards.count
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CloseButton { dismiss() }
                ProgressBar(value: Double(i) / Double(max(cards.count, 1)))
                Text("\(min(i + 1, cards.count))/\(cards.count)")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted).monospacedDigit()
            }
            .padding(.horizontal, 16)

            ZStack {
                if finished {
                    summary(t)
                } else {
                    ForEach(Array(cards.enumerated().dropFirst(i).prefix(3).reversed()), id: \.element.id) { k, card in
                        let depth = CGFloat(k - i)
                        if depth == 0 {
                            topCard(card, t)
                        } else {
                            CardShell { CardFace(card: card, t: t) }
                                .scaleEffect(1 - depth * 0.04)
                                .offset(y: depth * 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxHeight: .infinity)

            if !finished { actions(t) }
        }
    }

    private func topCard(_ card: WordCard, _ t: Strings) -> some View {
        let me = model.me
        let dx = leaving != 0 ? leaving * 600 : drag.width
        return CardShell {
            VStack(spacing: 0) {
                CardFace(card: card, t: t)
                if revealed {
                    VStack(spacing: 12) {
                        Divider().padding(.vertical, 6)
                        card.meaning.plain.font(.system(size: 22, weight: .heavy)).multilineTextAlignment(.center)
                        Button {
                            if let me { Speech.speak(card.example, me.target) }
                        } label: {
                            VStack(spacing: 6) {
                                card.example.plain.font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                                card.exampleTranslation.plain.font(.system(size: 14)).foregroundStyle(Theme.muted)
                            }
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                } else {
                    Text(t.tapToReveal).font(.system(size: 13)).foregroundStyle(Theme.muted).padding(.top, 20)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                if let me { Speech.speak(card.word, me.target) }
            } label: {
                Text("🔊").font(.system(size: 20)).frame(width: 44, height: 44)
            }
            .padding(8)
        }
        .overlay(alignment: .topLeading) {
            stamp(t.known, Theme.good).opacity(leaving == 1 ? 1 : Double(max(0, dx / 100))).padding(20)
        }
        .overlay(alignment: .topTrailing) {
            stamp(t.unknown, Theme.bad).opacity(leaving == -1 ? 1 : Double(max(0, -dx / 100))).padding(.top, 60).padding(.trailing, 20)
        }
        .offset(x: dx, y: leaving != 0 ? -40 : drag.height * 0.3)
        .rotationEffect(.degrees(Double(dx / 18)))
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { revealed.toggle() } }
        .gesture(
            DragGesture()
                .onChanged { if leaving == 0 { drag = $0.translation } }
                .onEnded { v in
                    if abs(v.translation.width) > threshold {
                        fly(v.translation.width > 0 ? 1 : -1)
                    } else {
                        withAnimation(.spring(duration: 0.3)) { drag = .zero }
                    }
                }
        )
        .zIndex(10)
    }

    private func stamp(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(-12))
    }

    private func actions(_ t: Strings) -> some View {
        HStack(alignment: .top, spacing: 28) {
            roundButton("xmark", t.unknown, Theme.bad, size: 64) { fly(-1) }
            roundButton("arrow.uturn.backward", t.undo, Theme.muted, size: 48) { Task { await undo() } }
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.4 : 1)
            roundButton("checkmark", t.known, Theme.good, size: 64) { fly(1) }
        }
        .padding(.bottom, 16)
    }

    private func roundButton(_ icon: String, _ label: String, _ color: Color, size: CGFloat,
                             action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: size, height: size)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.line, lineWidth: 2))
            }
            .accessibilityLabel(label)
            Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .frame(height: 90, alignment: .bottom)
    }

    private func summary(_ t: Strings) -> some View {
        let known = history.filter(\.known).count
        return CardShell {
            VStack(spacing: 12) {
                Text("🎉").font(.system(size: 56))
                Text(t.roundDone).font(.system(size: 22, weight: .heavy))
                Text(t.roundHint).font(.system(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                HStack(spacing: 40) {
                    stat(known, t.known, Theme.good)
                    stat(history.count - known, t.unknown, Theme.bad)
                }
                .padding(.vertical, 12)
                Button(t.goQuiz, action: goQuiz).buttonStyle(.chunky)
                Button(t.again) { Task { await load() } }.buttonStyle(.chunky(.ghost))
            }
        }
    }

    private func stat(_ n: Int, _ label: String, _ color: Color) -> some View {
        VStack {
            Text("\(n)").font(.system(size: 32, weight: .heavy)).foregroundStyle(color)
            Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
        }
    }

    private func fly(_ dir: CGFloat) {
        guard let cards, i < cards.count, !busy else { return }
        busy = true
        let idx = i
        let card = cards[idx]
        let known = dir > 0
        let elapsed = Int(Date().timeIntervalSince(shownAt) * 1000)
        let peeked = revealed
        withAnimation(.easeIn(duration: 0.26)) { leaving = dir }
        Task {
            async let wait: Void = Task.sleep(for: .milliseconds(260))
            do {
                let res = try await API.shared.reviewWord(card.id, known: known, peeked: peeked, elapsedMs: elapsed)
                try? await wait
                self.cards?[idx].apply(res.after)
                history.append((idx, known))
                i = idx + 1
                toast.show("\(card.word)  \(res.before.mastery) → \(res.after.mastery)")
            } catch {
                try? await wait
                if model.handle(error) { dismiss() } else { toast.show(model.t.error) }
            }
            leaving = 0
            resetCard()
            busy = false
        }
    }

    private func undo() async {
        guard let cards, let last = history.last, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let p = try await API.shared.undoWord(cards[last.idx].id)
            self.cards?[last.idx].apply(p)
            history.removeLast()
            i = last.idx
            resetCard()
            toast.show(model.t.undone)
        } catch {
            if model.handle(error) { dismiss() } else { toast.show(model.t.error) }
        }
    }
}

struct CardShell<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)  // on the shape only, not the text
            )
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Theme.line, lineWidth: 2))
    }
}

struct CardFace: View {
    let card: WordCard
    let t: Strings

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                LevelBars(level: card.level)
                Text(t.level[card.level]! + (card.level != .new ? " · \(card.mastery)" : ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.level(card.level))
                Spacer()
            }
            Spacer(minLength: 0)
            card.word.plain
                .font(.system(size: 40, weight: .heavy))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            HStack(spacing: 6) {
                Text(t.pos[card.pos] ?? card.pos).font(.system(size: 14)).foregroundStyle(Theme.muted)
                if card.gender != .none, let g = t.gender[card.gender] { GenderBadge(gender: card.gender, label: g) }
                if !card.topic.isEmpty { LvTag(text: card.custom == true ? t.custom : t.lv(card.difficultyLevel)) }
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview("Swipe") {
    SwipeView(goQuiz: {}).environment(AppModel.preview())
}
#endif
