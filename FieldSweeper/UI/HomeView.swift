import SwiftUI

/// 메모 패드처럼 정리된 첫 화면. 게임 카드를 눌러 들어간다.
struct HomeView: View {
    @State private var path: [GameKind] = []
    @State private var showStats = false
    @State private var showSettings = false
    /// 게임에서 돌아오면 카드의 진행·기록을 다시 읽는다.
    @State private var refresh = 0
    @AppStorage(AppLanguage.storageKey) private var language = "system"

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    VStack(spacing: 12) {
                        ForEach(GameKind.allCases) { kind in
                            GameCard(kind: kind, summary: .load(kind)) { path.append(kind) }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .id("\(language)-\(refresh)")
            }
            // 번호·날짜와 기록·설정은 화면 맨 아래에 고정한다. 게임이 늘어 카드가 스크롤돼도 항상 보인다.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 4) {
                    stamp
                    footer
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .background(Color(Paper.bg))
                .id("\(language)-\(refresh)")
            }
            .background(Color(Paper.bg).ignoresSafeArea())
            .foregroundStyle(Color(Paper.ink))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameKind.self) { kind in
                switch kind {
                case .minesweeper:
                    ContentView().toolbar(.hidden, for: .navigationBar)
                case .sudoku:
                    SudokuView().toolbar(.hidden, for: .navigationBar)
                case .shikaku:
                    ShikakuView().toolbar(.hidden, for: .navigationBar)
                case .futoshiki:
                    FutoshikiView().toolbar(.hidden, for: .navigationBar)
                }
            }
            .onChange(of: path) { _, new in if new.isEmpty { refresh += 1 } }
        }
        .sheet(isPresented: $showStats) { StatsView() }
        .sheet(isPresented: $showSettings) { AppSettingsView() }
        .environment(\.locale, AppLanguage.locale)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "nemo in nemo")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .kerning(-0.5)
            Text("네모 안에 네모 · 작은 네모 속, 커다란 생각.")
                .font(.caption)
                .foregroundStyle(Color(Paper.inkSoft))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(Paper.ink)).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// 주문서의 번호·날짜 칸. 번호는 지금까지 시작한 판 수.
    private var stamp: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Spacer()
            field("no.", String(format: "%03d", min(StatsStore.totalPlays, 999)))
            field("date.", Date.now.formatted(.dateTime.month(.defaultDigits).day().locale(AppLanguage.locale)))
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(Paper.rule)).frame(height: 1) }
        .accessibilityHidden(true)
    }

    private func field(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: name)
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Color(Paper.inkSoft))
            Text(verbatim: value).font(.system(size: 12)).monospacedDigit()
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 22) {
                footerButton("기록") { showStats = true }
                footerButton("설정") { showSettings = true }
            }
            Spacer()
            Text(verbatim: "nemo")
                .font(.system(size: 10, design: .serif))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(Ellipse().stroke(Color(Paper.ink), lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    private func footerButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().stroke(Color(Paper.ink), lineWidth: 1).frame(width: 11, height: 11)
                Text(title).font(.subheadline)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 카드 아래쪽 두 칸에 보여줄 내용. 이미 현재 언어로 바꾼 문구를 담는다.
struct GameSummary {
    var first: (label: String, value: String)
    var second: (label: String, value: String)

    @MainActor static func load(_ kind: GameKind) -> GameSummary {
        guard kind.isAvailable else {
            return GameSummary(first: (tr("진행"), tr("준비 중")), second: (tr("최고 기록"), "—"))
        }
        switch kind {
        case .minesweeper:
            let progress = SaveStore.load().map { "\(Int(($0.progress * 100).rounded()))% · " + tr("이어하기") } ?? tr("새 게임")
            let config = DeviceClass.current.resolve(Persist.lastConfig)
            let best = RecordStore.best(for: config.recordKey).map(clock) ?? "—"
            return GameSummary(first: (tr("진행"), progress), second: (tr("최고 기록") + " · " + tr(config.name), best))
        case .sudoku:
            let progress = SudokuSave.load().map { "\(Int(($0.progress * 100).rounded()))% · " + tr("이어하기") } ?? tr("새 게임")
            let level = SudokuSave.load()?.puzzle.level
                ?? SudokuLevel(rawValue: UserDefaults.standard.integer(forKey: "sudoku.lastLevel")) ?? .medium
            let best = StatsStore.load(.sudoku).bestByDifficulty[level.name].map(clock) ?? "—"
            return GameSummary(first: (tr("진행"), progress), second: (tr("최고 기록") + " · " + tr(level.name), best))
        case .shikaku:
            let saved = ShikakuSave.load()
            let progress = saved.map { "\(Int(($0.progress * 100).rounded()))% · " + tr("이어하기") } ?? tr("새 게임")
            let level = saved?.puzzle.level
                ?? ShikakuLevel(rawValue: UserDefaults.standard.integer(forKey: "shikaku.lastLevel")) ?? .medium
            let best = StatsStore.load(.shikaku).bestByDifficulty[level.name].map(clock) ?? "—"
            return GameSummary(first: (tr("진행"), progress), second: (tr("최고 기록") + " · " + tr(level.name), best))
        case .futoshiki:
            let saved = FutoshikiSave.load()
            let progress = saved.map { "\(Int(($0.progress * 100).rounded()))% · " + tr("이어하기") } ?? tr("새 게임")
            let level = saved?.puzzle.level
                ?? FutoshikiLevel(rawValue: UserDefaults.standard.integer(forKey: "futoshiki.lastLevel")) ?? .medium
            let best = StatsStore.load(.futoshiki).bestByDifficulty[level.name].map(clock) ?? "—"
            return GameSummary(first: (tr("진행"), progress), second: (tr("최고 기록") + " · " + tr(level.name), best))
        }
    }
}

struct GameCard: View {
    let kind: GameKind
    let summary: GameSummary
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tr(kind.title))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color(kind.text))
                    Spacer()
                    Text(verbatim: kind.number)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(Color(Paper.inkSoft))
                }
                HStack(alignment: .top, spacing: 10) {
                    cell(summary.first)
                    cell(summary.second)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .background(Color(kind.fill), in: RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!kind.isAvailable)
        .accessibilityElement(children: .combine)
    }

    private func cell(_ item: (label: String, value: String)) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: item.label).foregroundStyle(Color(kind.text))
            Text(verbatim: item.value).foregroundStyle(Color(kind.text))
        }
        .font(.system(size: 11))
        .lineSpacing(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
