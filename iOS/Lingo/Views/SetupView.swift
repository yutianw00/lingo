import SwiftUI

/// Pick native + target language (first run), and account / server settings later.
struct SetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let firstRun: Bool

    @State private var native: Lang = .zh
    @State private var target: Lang = .en
    @State private var saving = false
    @State private var failed = false
    @State private var server = API.shared.server

    var body: some View {
        let t = Strings.for(native)  // preview the UI in the language being picked
        let me = model.me
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if !firstRun { CloseButton { dismiss() } }
                    Text(t.getStarted).font(.system(size: 22, weight: .heavy))
                }
                .padding(.bottom, 4)
                SectionTitle(text: t.myLanguage)
                grid(t, selected: native, disabled: nil) { pickNative($0) }
                SectionTitle(text: t.iWantToLearn)
                grid(t, selected: target, disabled: native) { target = $0 }
                Text(t.learningPair(t.langName[native]!, t.langName[target]!))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24).padding(.bottom, 8)
                if failed {
                    Text(t.error).font(.system(size: 14)).foregroundStyle(Theme.bad).frame(maxWidth: .infinity)
                }
                if let me, let email = me.email {
                    SectionTitle(text: t.account)
                    Panel {
                        HStack(spacing: 12) {
                            AsyncImage(url: me.picture.flatMap(URL.init(string:))) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(Theme.muted)
                            }
                            .frame(width: 40, height: 40).clipShape(Circle())
                            VStack(alignment: .leading) {
                                (me.name ?? "").plain.font(.system(size: 15, weight: .bold))
                                email.plain.font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Button(t.signOut) { Task { await model.signOut() } }
                                .font(.system(size: 13, weight: .bold))
                                .buttonStyle(.bordered)
                        }
                    }
                }
                if !firstRun {
                    SectionTitle(text: t.server)
                    ServerField(server: $server)
                        .onSubmit { applyServer() }
                }
                Button(firstRun ? t.start : t.save) { Task { await save() } }
                    .buttonStyle(.chunky)
                    .disabled(saving)
                    .padding(.top, 28)
            }
            .padding(16)
        }
        .background(Theme.bg)
        .onAppear {
            if let me = model.me {
                native = me.native
                target = me.target == me.native ? Lang.allCases.first { $0 != me.native }! : me.target
            }
        }
    }

    private func pickNative(_ l: Lang) {
        native = l
        if target == l { target = Lang.allCases.first { $0 != l }! }
    }

    private func applyServer() {
        guard server != API.shared.server else { return }
        API.shared.server = server
        API.shared.token = nil
        Task { await model.load() }
    }

    private func save() async {
        if server != API.shared.server { applyServer(); return }
        saving = true
        failed = false
        defer { saving = false }
        do {
            model.update(try await API.shared.saveMe(native: native, target: target))
            if !firstRun { dismiss() }
        } catch {
            if !model.handle(error) { failed = true }
        }
    }

    private func grid(_ t: Strings, selected: Lang, disabled: Lang?, pick: @escaping (Lang) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Lang.allCases) { l in
                let on = l == selected
                Button { pick(l) } label: {
                    HStack(spacing: 10) {
                        LangBadge(lang: l)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t.langName[l]!).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                            Text(l.selfName).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(on ? Theme.soft : Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? Theme.primary : Theme.line, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(l == disabled)
                .opacity(l == disabled ? 0.35 : 1)
            }
        }
    }
}
