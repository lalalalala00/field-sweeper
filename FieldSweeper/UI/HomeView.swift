import SwiftUI

/// 메모 패드처럼 정리된 첫 화면. 게임 카드를 눌러 들어간다.
struct HomeView: View {
    @State private var path: [GameKind] = []
    @State private var showStats = false
    @State private var showSettings = false
    /// 게임에서 돌아오면 카드의 진행·기록을 다시 읽는다.
    @State private var refresh = 0
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    /// 마지막에 연 게임. 헤더 번호 줄에서 동그라미를 친다(웹과 같다).
    @AppStorage("lastGame") private var lastGame = ""
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 양옆 여백. iPhone은 카드를 넓게 쓰도록 좁힌다(웹 index.html과 같다).
    private var sidePadding: CGFloat { sizeClass == .compact ? 20 : 28 }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(GameKind.allCases) { kind in
                        GameCard(kind: kind, summary: .load(kind)) { path.append(kind) }
                            .id(kind)
                    }
                }
                .padding(.horizontal, sidePadding)
                // iPhone에서는 번호 줄 바로 아래에서 카드가 시작된다(웹과 같다).
                .padding(.top, sizeClass == .compact ? 6 : 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .id("\(language)-\(refresh)")
            }
            // 이름·소개·선은 위에 고정하고, 게임 카드만 스크롤된다.
            .safeAreaInset(edge: .top, spacing: 0) {
                header { kind in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(kind, anchor: .top) }
                }
                    .padding(.horizontal, sidePadding)
                    .padding(.top, 28)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .background(Color(Paper.bg))
                    .id(language)
            }
            // 번호·날짜와 기록·설정은 화면 맨 아래에 고정한다. 게임이 늘어 카드가 스크롤돼도 항상 보인다.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 4) {
                    stamp
                    footer
                }
                .padding(.horizontal, sidePadding)
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
                case .mirror:
                    MirrorView().toolbar(.hidden, for: .navigationBar)
                case .pair:
                    PairView().toolbar(.hidden, for: .navigationBar)
                case .switchSquares:
                    SwitchView().toolbar(.hidden, for: .navigationBar)
                case .calc:
                    CalcView().toolbar(.hidden, for: .navigationBar)
                case .star:
                    StarView().toolbar(.hidden, for: .navigationBar)
                }
            }
            .onChange(of: path) { _, new in
                if let kind = new.last { lastGame = kind.rawValue }
                if new.isEmpty { refresh += 1 }
            }
            }
        }
        .sheet(isPresented: $showStats) { StatsView() }
        .sheet(isPresented: $showSettings) { AppSettingsView() }
        .environment(\.locale, AppLanguage.locale)
    }

    /// 제목, 소개, 구분선, 게임 번호 줄. 넓으면 소개와 번호가 한 줄, iPhone에서는 번호가 선 아래 오른쪽으로 내려간다.
    private func header(jump: @escaping (GameKind) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "nemo in nemo")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .kerning(-0.5)
                .accessibilityAddTraits(.isHeader)
            if sizeClass == .compact {
                tagline
                Rectangle().fill(Color(Paper.ink)).frame(height: 1).padding(.top, 8)
                HStack {
                    Spacer()
                    numbers(jump: jump)
                }
                .padding(.top, 2)
                .padding(.bottom, 4)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    tagline
                    Spacer()
                    numbers(jump: jump)
                }
                Rectangle().fill(Color(Paper.ink)).frame(height: 1).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tagline: some View {
        Text("네모 안에 네모 · 작은 네모 속, 커다란 생각.")
            .font(.caption)
            .foregroundStyle(Color(Paper.inkSoft))
    }

    /// 게임 번호 줄: 누르면 그 카드로, 마지막에 연 게임에는 연필로 친 듯한 동그라미.
    private func numbers(jump: @escaping (GameKind) -> Void) -> some View {
        HStack(spacing: 1) {
            ForEach(Array(GameKind.allCases.enumerated()), id: \.element) { k, kind in
                let isLast = kind.rawValue == lastGame
                Button { jump(kind) } label: {
                    Text(verbatim: "\(k + 1)")
                        .font(.system(size: 11, weight: isLast ? .semibold : .regular, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(Color(isLast ? Paper.ink : Paper.inkSoft))
                        .frame(width: 16, height: 18)
                        .overlay {
                            if isLast {
                                PencilCircle()
                                    .stroke(Color(Paper.ink), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                                    .padding(.horizontal, -5)
                                    .padding(.vertical, -3)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.horizontal, isLast ? 4 : 0)
                        // 보이는 크기는 그대로 두고 누르는 영역만 위아래로 넓힌다.
                        .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: kind.title))
                .accessibilityAddTraits(isLast ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("게임 바로 가기")
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
                // 체크 칸 같은 작은 네모(테두리를 조금 두껍게)
                RoundedRectangle(cornerRadius: 1.5)
                    .strokeBorder(Color(Paper.ink), lineWidth: 2.5)
                    .frame(width: 14, height: 14)
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

    /// 진행 중인 판이 있으면 진행률과 이어하기, 최고 기록은 그 판(없으면 마지막으로 고른) 난이도 것.
    @MainActor static func summary(_ kind: GameKind, progress: Double?, saved: String?, last: String?) -> GameSummary {
        let text = progress.map { "\(Int(($0 * 100).rounded()))% · " + tr("이어하기") } ?? tr("새 게임")
        let level = saved ?? last ?? "초급"
        let best = StatsStore.load(kind).bestByDifficulty[level].map(clock) ?? "—"
        return GameSummary(first: (tr("진행"), text), second: (tr("최고 기록") + " · " + tr(level), best))
    }

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
        case .mirror:
            return summary(kind, progress: MirrorSave.load()?.progress, saved: MirrorSave.load()?.puzzle.level.name,
                           last: MirrorLevel(rawValue: UserDefaults.standard.integer(forKey: "mirror.lastLevel"))?.name)
        case .pair:
            return summary(kind, progress: PairSave.load()?.progress, saved: PairSave.load()?.puzzle.level.name,
                           last: PairLevel(rawValue: UserDefaults.standard.integer(forKey: "pair.lastLevel"))?.name)
        case .switchSquares:
            return summary(kind, progress: SwitchSave.load()?.progress, saved: SwitchSave.load()?.puzzle.level.name,
                           last: SwitchLevel(rawValue: UserDefaults.standard.integer(forKey: "switch.lastLevel"))?.name)
        case .calc:
            return summary(kind, progress: CalcSave.load()?.progress, saved: CalcSave.load()?.puzzle.level.name,
                           last: CalcLevel(rawValue: UserDefaults.standard.integer(forKey: "calc.lastLevel"))?.name)
        case .star:
            return summary(kind, progress: StarSave.load()?.progress, saved: StarSave.load()?.puzzle.level.name,
                           last: StarLevel(rawValue: UserDefaults.standard.integer(forKey: "star.lastLevel"))?.name)
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
                    HStack(spacing: 8) {
                        GameSymbol(kind: kind, size: 17, color: Color(kind.text))
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                        GameName(kind: kind, color: Color(kind.text))
                    }
                    Spacer()
                    WeightSquares(weight: kind.weight, color: Color(kind.text))
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        .padding(.trailing, 4)
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

/// 게임 자체 난이도: 작은 네모 세 개 중 채운 수(1 쉬움, 2 보통, 3 어려움).
private struct WeightSquares: View {
    let weight: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { w in
                RoundedRectangle(cornerRadius: 1.5)
                    .strokeBorder(color, lineWidth: 1.2)
                    .background(RoundedRectangle(cornerRadius: 1.5).fill(w <= weight ? color : .clear))
                    .frame(width: 7, height: 7)
            }
        }
        .opacity(0.7)
        .accessibilityElement()
        // 읽을 때는 이미 번역이 있는 '쉬움·보통·어려움'만 읽는다.
        .accessibilityLabel(Text(LocalizedStringKey(["쉬움", "보통", "어려움"][max(1, min(weight, 3)) - 1])))
    }
}

/// 연필로 한 번 휙 그은 듯한 동그라미(웹 index.html의 번호 줄 동그라미와 같은 곡선, 30×32 기준).
private struct PencilCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30, sy = rect.height / 32
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(8, 7))
        path.addCurve(to: p(27, 12), control1: p(12, 2), control2: p(25, 3))
        path.addCurve(to: p(12, 28), control1: p(29, 22), control2: p(20, 30))
        path.addCurve(to: p(5, 10), control1: p(4, 26), control2: p(1, 17))
        path.addCurve(to: p(16, 5.5), control1: p(7, 7), control2: p(11, 5))
        return path
    }
}
