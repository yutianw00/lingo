import SwiftUI

/// Searchable word list with mastery and next-review time.
struct WordsView: View {
    @Environment(AppModel.self) private var model
    @State private var words: [WordCard]?
    @State private var failed = false
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var lv = 0  // 0 = all difficulty levels
    @State private var now = Date().timeIntervalSince1970

    enum Filter: Hashable, CaseIterable {
        case all, new, learning, familiar, mastered, due
        var level: Level? {
            switch self {
            case .new: .new
            case .learning: .learning
            case .familiar: .familiar
            case .mastered: .mastered
            default: nil
            }
        }
    }

    var body: some View {
        let t = model.t
        NavigationStack {
            Group {
                if let words {
                    list(words, t)
                } else if failed {
                    Message(text: t.error, action: (t.retry, { Task { await load() } }))
                } else {
                    Message(text: t.loading)
                }
            }
            .background(Theme.bg)
            .navigationTitle(t.wordsTitle)
            .toolbar {
                if let me = model.me, let words {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(t.langName[me.target]!) · \(t.total(words.count))")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .task(id: model.me?.target) { await load() }
    }

    private func load() async {
        do {
            words = try await API.shared.words()
            now = Date().timeIntervalSince1970
            failed = false
        } catch {
            if !model.handle(error) { failed = true }
        }
    }

    private func remove(_ w: WordCard) async {
        do {
            try await API.shared.removeWord(w.id)
            words?.removeAll { $0.id == w.id }
        } catch {
            _ = model.handle(error)
        }
    }

    private func shown(_ words: [WordCard]) -> [WordCard] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return words.filter { w in
            if filter == .due { guard let d = w.due, d <= now else { return false } }
            else if let l = filter.level, w.level != l { return false }
            if lv == -1 { if w.custom != true { return false } } else if lv != 0, w.difficultyLevel != lv { return false }
            return needle.isEmpty || w.word.lowercased().contains(needle) || w.meaning.lowercased().contains(needle)
        }
    }

    private func label(_ f: Filter, _ t: Strings) -> String {
        switch f {
        case .all: t.all
        case .due: t.dueNow
        default: t.level[f.level!]!
        }
    }

    private func list(_ words: [WordCard], _ t: Strings) -> some View {
        let rows = shown(words)
        let leveled = words.contains { !$0.topic.isEmpty && $0.custom != true }
        let hasCustom = words.contains { $0.custom == true }
        return List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases, id: \.self) { f in
                            let on = f == filter
                            Button { filter = f } label: {
                                Text(label(f, t))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(on ? Theme.primary : Theme.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(on ? Theme.soft : Theme.card, in: Capsule())
                                    .overlay(Capsule().strokeBorder(on ? Theme.primary : Theme.line, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                        if leveled || hasCustom {
                            Picker("Lv", selection: $lv) {
                                Text(t.all).tag(0)
                                if hasCustom { Text(t.custom).tag(-1) }
                                if leveled { ForEach(1...10, id: \.self) { Text(t.lv($0)).tag($0) } }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }
            Section {
                if rows.isEmpty {
                    Text(t.noMatch).foregroundStyle(Theme.muted)
                }
                ForEach(rows) { w in
                    row(w, t).swipeActions {
                        if w.custom == true {
                            Button(t.remove, role: .destructive) { Task { await remove(w) } }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $query, prompt: t.search)
        .refreshable { await load() }
    }

    private func row(_ w: WordCard, _ t: Strings) -> some View {
        Button {
            if let me = model.me { Speech.speak(w.word, me.target) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    w.word.plain.font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
                    HStack(spacing: 4) {
                        if !w.topic.isEmpty { LvTag(text: w.custom == true ? t.custom : t.lv(w.difficultyLevel)) }
                        if w.gender != .none { GenderBadge(gender: w.gender, label: w.gender == .mf ? "m/f" : w.gender.rawValue) }
                        w.meaning.plain.font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(Theme.level(w.level)).frame(width: g.size.width * Double(max(w.mastery, 4)) / 100)
                        }
                    }
                    .frame(width: 70, height: 6)
                    let d = dueLabel(w, t)
                    Text(t.level[w.level]! + (w.level != .new ? " \(w.mastery)" : "") + " · " + d.text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(d.now ? Theme.warnDark : Theme.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dueLabel(_ w: WordCard, _ t: Strings) -> (text: String, now: Bool) {
        guard let due = w.due else { return (t.notLearned, false) }
        let secs = due - now
        if secs <= 0 { return (t.dueNow, true) }
        if secs < 86400 { return (t.inHours(max(1, Int((secs / 3600).rounded()))), false) }
        return (t.inDays(Int((secs / 86400).rounded())), false)
    }
}
