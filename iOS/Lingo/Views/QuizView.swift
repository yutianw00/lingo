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
    @State private var words: QuestionWords?
    @State private var picked: Int?  // index into words.tokens

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
        words = nil
        picked = nil
        startedAt = Date()
    }

    /// Words become tappable once their meanings arrive (the server usually prefetched them).
    private func loadWords(_ q: Question) async {
        guard words?.text != q.prompt else { return }
        if let w = try? await API.shared.questionWords(q.id), qs?.indices.contains(n) == true, qs?[n].id == q.id {
            words = w
        }
    }

    private func add(_ tok: WordToken, _ q: Question) async {
        guard let meaning = tok.lemmaMeaning ?? tok.meaning else { return }
        let word = tok.lemma ?? tok.text
        do {
            _ = try await API.shared.addWord(word, meaning: meaning, pos: tok.pos ?? "", questionId: q.id)
            let key = word.lowercased()
            words?.tokens = words?.tokens.map { x in
                var x = x
                if (x.lemma ?? x.text).lowercased() == key { x.added = true }
                return x
            } ?? []
        } catch {
            if model.handle(error) { dismiss() }
        }
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
                            .tint(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .environment(\.openURL, OpenURLAction { url in
                                // Tapped word: lingo-word://<token index>
                                if url.scheme == "lingo-word", let i = Int(url.host() ?? "") {
                                    withAnimation(.snappy) { picked = picked == i ? nil : i }
                                }
                                return .handled
                            })
                        Spacer(minLength: 8)
                        Button {
                            if let me = model.me { Speech.speak(isFill ? q.prompt.replacingOccurrences(of: "___", with: "…") : q.prompt, me.target) }
                        } label: { Text("🔊").font(.system(size: 20)) }
                    }

                    if let picked, let tok = words?.tokens[safe: picked] {
                        glossCard(tok, q, t)
                    } else {
                        Button { showTr = true } label: {
                            (Text(translationShown ? q.translation : "👁 \(t.showTranslation)")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                            + Text(words == nil ? "" : " · \(t.tapWordHint)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted.opacity(0.8)))
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                    }

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
        .task(id: q.id) { await loadWords(q) }
        .overlay(alignment: .bottom) {
            if let result { resultSheet(result, t).transition(.move(edge: .bottom)) }
        }
        .ignoresSafeArea(edges: result == nil ? [] : .bottom)
    }

    private func promptText(_ q: Question, _ parts: [String], _ isFill: Bool) -> Text {
        let filled = result?.answer ?? sel ?? String(repeating: "\u{00A0}", count: 8)  // NBSP: plain spaces drop the underline
        // After checking, the blank always holds the correct answer, so it is green even on a miss.
        let color: Color = result == nil ? Theme.primary : Theme.good
        var blank = AttributedString(" \(filled) ")
        blank.foregroundColor = color
        blank.underlineStyle = Text.LineStyle(pattern: .solid, color: color)

        // Tap-to-translate: every word is a link the openURL handler turns into a word card.
        if let words, words.text == q.prompt {
            var out = AttributedString()
            for (i, tok) in words.tokens.enumerated() {
                if tok.word {
                    var w = AttributedString(tok.text)
                    w.link = URL(string: "lingo-word://\(i)")
                    w.underlineStyle = Text.LineStyle(pattern: .dot, color: Theme.muted.opacity(0.5))
                    if picked == i { w.backgroundColor = Theme.soft; w.foregroundColor = Theme.primary }
                    out += w
                } else {
                    for (j, part) in tok.text.components(separatedBy: "___").enumerated() {
                        if j > 0 { out += blank }
                        out += AttributedString(part)
                    }
                }
            }
            return Text(out)
        }
        guard isFill, parts.count == 2 else { return q.prompt.plain }
        return Text(AttributedString(parts[0]) + blank + AttributedString(parts[1]))
    }

    private func glossCard(_ tok: WordToken, _ q: Question, _ t: Strings) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    if let me = model.me { Speech.speak(tok.lemma ?? tok.text, me.target) }
                } label: {
                    HStack(spacing: 4) {
                        Text(verbatim: "🔊 \(tok.text)").font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                        if let lemma = tok.lemma, lemma.lowercased() != tok.text.lowercased() {
                            Text(verbatim: "→ \(lemma)").font(.system(size: 14)).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .buttonStyle(.plain)
                if let pos = tok.pos, !pos.isEmpty { LvTag(text: t.pos[pos] ?? pos) }
                Spacer()
                Button { withAnimation(.snappy) { picked = nil } } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }
            if let meaning = tok.meaning {
                meaning.plain.font(.system(size: 15)).foregroundStyle(Theme.ink)
                if let lm = tok.lemmaMeaning, lm != meaning, let lemma = tok.lemma {
                    Text(verbatim: "\(lemma): \(lm)").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                let added = tok.added == true
                Button {
                    Task { await add(tok, q) }
                } label: {
                    Text(added ? t.wordAdded : "＋ \(t.addWord)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(added ? Theme.goodDark : Theme.primary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(added)
                .padding(.top, 4)
            } else {
                Text(t.noGloss).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.primary, lineWidth: 2))
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
            if let why = r.explanation {
                Text(verbatim: "💡 \(why)").font(.system(size: 14)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !r.correct, let whyNot = r.choiceExplanation, let sel {
                (Text(verbatim: "\(t.yourChoice) “\(sel)”: ").bold().foregroundStyle(Theme.badDark)
                    + Text(verbatim: whyNot).foregroundStyle(Theme.ink))
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
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

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

#if DEBUG
#Preview("Quiz") {
    QuizView(goSwipe: {}).environment(AppModel.preview())
}
#endif
