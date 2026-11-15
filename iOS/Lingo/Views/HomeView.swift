import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var data: HomeData?
    @State private var failed = false
    @State private var cover: Cover?
    @State private var showSetup = false

    enum Cover: String, Identifiable {
        case swipe, quiz
        var id: String { rawValue }
    }

    var body: some View {
        let t = model.t
        Group {
            if let data, let me = model.me {
                content(data, me, t)
            } else if failed {
                Message(text: t.error, action: (t.retry, { Task { await load() } }))
            } else {
                Message(text: t.loading)
            }
        }
        .task(id: model.me.map { "\($0.native.rawValue)\($0.target.rawValue)" }) { await load() }
        .fullScreenCover(item: $cover, onDismiss: { Task { await load() } }) { c in
            switch c {
            case .swipe: SwipeView(goQuiz: { cover = .quiz })
            case .quiz: QuizView(goSwipe: { cover = .swipe })
            }
        }
        .sheet(isPresented: $showSetup) { SetupView(firstRun: false) }
        .onAppear {
            switch DebugLaunch.screen {
            case "swipe": cover = .swipe
            case "quiz": cover = .quiz
            case "setup": showSetup = true
            default: break
            }
        }
    }

    private func load() async {
        do {
            data = try await API.shared.home()
            failed = false
        } catch {
            if !model.handle(error) { failed = true }
        }
    }

    private func content(_ d: HomeData, _ me: Me, _ t: Strings) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button { showSetup = true } label: {
                        HStack(spacing: 6) {
                            LangBadge(lang: me.native, size: 26)
                            Text("→").foregroundStyle(Theme.muted)
                            LangBadge(lang: me.target, size: 26)
                            Text("\(t.langName[me.target]!) ▾").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.ink)
                        }
                        .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 5)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 2))
                    }
                    if d.leveled {
                        Text(t.lv(d.level))
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.soft, in: Capsule())
                    }
                    Spacer()
                    Text("🔥 \(t.streakDays(d.streak))").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.warnDark)
                }
                .padding(.bottom, 16)

                goal(d, t)

                SectionTitle(text: t.practice)
                mode(icon: "🃏", tint: Theme.soft, title: t.swipeTitle, desc: t.swipeDesc) {
                    if d.words.due > 0 { Tag(text: t.due(d.words.due), fg: Theme.warnDark, bg: Theme.warnSoft) }
                    Tag(text: t.newCount(d.words.new), fg: Theme.goodDark, bg: Theme.goodSoft)
                } action: { cover = .swipe }
                mode(icon: "✅", tint: Theme.goodSoft, title: t.quizTitle, desc: t.quizDesc) {
                    Tag(text: t.perRound(10), fg: Theme.primary, bg: Theme.soft)
                    if d.quiz.mistakes > 0 { Tag(text: t.mistakes(d.quiz.mistakes), fg: Theme.badDark, bg: Theme.badSoft) }
                    if d.quiz.due > 0 { Tag(text: t.due(d.quiz.due), fg: Theme.warnDark, bg: Theme.warnSoft) }
                } action: { cover = .quiz }
                .padding(.top, 12)

                SectionTitle(text: t.vocab, detail: t.total(d.words.total))
                Panel { Distribution(levels: d.words.levels, total: d.words.total, t: t) }
                SectionTitle(text: t.quizProgress, detail: t.total(d.quiz.total))
                Panel { Distribution(levels: d.quiz.levels, total: d.quiz.total, t: t) }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .refreshable { await load() }
    }

    private func goal(_ d: HomeData, _ t: Strings) -> some View {
        let pct = min(1, Double(d.today.done) / Double(max(d.today.goal, 1)))
        return Panel {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 8)
                    Circle().trim(from: 0, to: pct).stroke(Theme.good, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(d.today.done)/\(d.today.goal)").font(.system(size: 14, weight: .heavy))
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.dailyGoal(d.today.goal)).font(.system(size: 16, weight: .heavy))
                    Text(d.today.done >= d.today.goal ? t.goalDone : t.remaining(d.today.goal - d.today.done))
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func mode(icon: String, tint: Color, title: String, desc: String,
                      @ViewBuilder tags: () -> some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Panel {
                HStack(alignment: .top, spacing: 14) {
                    Text(icon).font(.system(size: 26)).frame(width: 52, height: 52)
                        .background(tint, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text(desc).font(.system(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                        HStack(spacing: 6) { tags() }.padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct Distribution: View {
    let levels: LevelCounts
    let total: Int
    let t: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { g in
                HStack(spacing: 0) {
                    ForEach(Level.allCases, id: \.self) { l in
                        Theme.level(l).frame(width: g.size.width * Double(levels[l]) / Double(max(total, 1)))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .background(Theme.line, in: Capsule())
            FlowRow {
                ForEach(Level.allCases, id: \.self) { l in
                    HStack(spacing: 5) {
                        Circle().fill(Theme.level(l)).frame(width: 8, height: 8)
                        Text("\(t.level[l]!) \(levels[l])").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }
}

/// Wrapping horizontal layout for the legend.
struct FlowRow: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += row + 6; row = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            row = max(row, size.height)
        }
        return CGSize(width: maxX, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += row + 6; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
