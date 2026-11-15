import SwiftUI

/// Multiple choice: fill the blank / what comes next.
struct QuizView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goSwipe: () -> Void

    @State private var qs: [Question]?
    @State private var failed = false
    @State private var n = 0
    @State private var sel: String?
    @State private var result: AnswerResult?
    @State private var showTr = false
    @State private var checking = false
    @State private var score = 0
    @State private var startedAt = Date()

    var body: some View {
        let t = model.t
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let qs {
                if qs.isEmpty {
                    VStack {
                        HStack { CloseButton { dismiss() }; Spacer() }.padding(.horizontal, 16)
                        Message(text: t.quizLocked, action: (t.goSwipe, goSwipe))
                    }
                } else if n >= qs.count {
                    done(qs.count, t)
                } else {
                    question(qs[n], qs.count, t)
                }
            } else if failed {
                Message(text: t.error, action: (t.retry, { Task { await load() } }))
            } else {
                Message(text: t.loading)
            }
        }
        .task { await load() }
    }

    private func load() async {
        qs = nil
        failed = false
        do {
            qs = try await API.shared.quizSession(size: 10)
            n = 0
            score = 0
            reset()
        } catch {
            if model.handle(error) { dismiss() } else { failed = true }
        }
    }

    private func reset() {
        sel = nil
        result = nil
        showTr = false
        startedAt = Date()
    }

    private func check(_ q: Question) async {
        guard let sel, result == nil, !checking else { return }
        checking = true
        defer { checking = false }
        do {
            let r = try await API.shared.answer(q.id, choice: sel, elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000))
            withAnimation(.spring(duration: 0.3)) { result = r }
            if r.correct { score += 1 }
            if let me = model.me { Speech.speak(r.fullSentence, me.target) }
        } catch {
            if model.handle(error) { dismiss() } else { failed = true; qs = nil }
        }
    }

    private func question(_ q: Question, _ count: Int, _ t: Strings) -> some View {
        let isFill = q.kind == .fill
        let typeLabel = q.legacy ? (isFill ? t.fill : t.next) : t.skill[q.skill]!
        let hint = q.skill == .vocab ? t.vocabHint : isFill ? (q.legacy ? t.fillHint : t.formHint) : t.nextHint
        let translationShown = showTr || result != nil || q.skill == .vocab
        let parts = q.prompt.components(separatedBy: "___")

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                CloseButton { dismiss() }
                ProgressBar(value: Double(n) / Double(count))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Tag(text: typeLabel, fg: Theme.primary, bg: Theme.soft)
                        if !q.legacy { Tag(text: t.lv(q.difficultyLevel), fg: Theme.muted, bg: Theme.line) }
                    }
                    Text(hint).font(.system(size: 13)).foregroundStyle(Theme.muted)

                    HStack(alignment: .top) {
                        promptText(q, parts, isFill)
                            .font(.system(size: 22, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button {
                            if let me = model.me { Speech.speak(isFill ? q.prompt.replacingOccurrences(of: "___", with: "…") : q.prompt, me.target) }
                        } label: { Text("🔊").font(.system(size: 20)) }
                    }

                    Button { showTr = true } label: {
                        Text(translationShown ? q.translation : "👁 \(t.showTranslation)")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)

                    options(q, isFill)
                }
                .padding(.vertical, 20)
            }
            if result == nil {
                Button(t.check) { Task { await check(q) } }
                    .buttonStyle(.chunky)
                    .disabled(sel == nil || checking)
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            if let result { resultSheet(result, t).transition(.move(edge: .bottom)) }
        }
        .ignoresSafeArea(edges: result == nil ? [] : .bottom)
    }

    private func promptText(_ q: Question, _ parts: [String], _ isFill: Bool) -> Text {
        guard isFill, parts.count == 2 else { return q.prompt.plain }
        let filled = result?.answer ?? sel ?? "      "
        // After checking, the blank always holds the correct answer, so it is green even on a miss.
        let color: Color = result == nil ? Theme.primary : Theme.good
        return parts[0].plain + Text(verbatim: " \(filled) ").foregroundStyle(color).underline() + parts[1].plain
    }

    private func options(_ q: Question, _ isFill: Bool) -> some View {
        let columns = isFill ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)] : [GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(q.options, id: \.text) { o in
                let style = optionStyle(o.text)
                Button { if result == nil { sel = o.text } } label: {
                    VStack(alignment: isFill ? .center : .leading, spacing: 4) {
                        o.text.plain.font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        if !isFill, result != nil, let tr = o.translation {
                            tr.plain.font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .multilineTextAlignment(isFill ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: isFill ? .center : .leading)
                    .padding(14)
                    .background(style.bg, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(style.border, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(result != nil)
            }
        }
    }

    private func optionStyle(_ text: String) -> (bg: Color, border: Color) {
        if let result {
            if text == result.answer { return (Theme.goodSoft, Theme.good) }
            if text == sel { return (Theme.badSoft, Theme.bad) }
            return (Theme.card, Theme.line)
        }
        return sel == text ? (Theme.soft, Theme.primary) : (Theme.card, Theme.line)
    }

    private func resultSheet(_ r: AnswerResult, _ t: Strings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(r.correct ? "✓ \(t.correct)" : "✕ \(t.correctAnswer)\(r.answer)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(r.correct ? Theme.goodDark : Theme.badDark)
            Button {
                if let me = model.me { Speech.speak(r.fullSentence, me.target) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "🔊 \(r.fullSentence)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    r.translation.plain.font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            Button(t.continue) {
                withAnimation { n += 1; reset() }
            }
            .buttonStyle(.chunky(r.correct ? .good : .bad))
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(r.correct ? Theme.goodSoft : Theme.badSoft)
    }

    private func done(_ count: Int, _ t: Strings) -> some View {
        let pct = Int((Double(score) / Double(max(count, 1)) * 100).rounded())
        return VStack(spacing: 14) {
            Spacer()
            Text(pct >= 80 ? "🏆" : "💪").font(.system(size: 64))
            Text(t.quizDone).font(.system(size: 24, weight: .heavy))
            Text(t.accuracy(pct)).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.good)
            Text(t.quizDoneHint).font(.system(size: 13)).foregroundStyle(Theme.muted)
            Spacer()
            Button(t.again) { Task { await load() } }.buttonStyle(.chunky)
            Button(t.backHome) { dismiss() }.buttonStyle(.chunky(.ghost))
        }
        .padding(16)
    }
}
