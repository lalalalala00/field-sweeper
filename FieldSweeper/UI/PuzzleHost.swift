import SwiftUI

/// 난이도 고르기 목록에 보일 한 줄.
struct PuzzleLevelInfo: Identifiable {
    let id: Int
    /// 기록에도 쓰는 한국어 이름(초급…).
    let name: String
    let detail: String
    /// 메뉴에 보일 이름. 없으면 "이름 · detail".
    var menuLabel: String?
}

/// 거울네모·짝네모·스위치네모·셈네모·별네모가 함께 쓰는 화면 틀:
/// 상단 바, 난이도 고르기, 퍼즐을 만드는 동안의 창, 일시정지, 완성 창, 자동 저장, 앱 전환 처리.
struct PuzzleHost<Game: HostedPuzzle & Observable, Board: View, Status: View, Controls: View, ExtraMenu: View, Extra: View>: View {
    let kind: GameKind
    let game: Game
    let levels: [PuzzleLevelInfo]
    let subtitle: String
    /// 새 판을 만들어 시작한다(오래 걸리면 안에서 따로 돌린다). 끝나면 돌아온다.
    let makePuzzle: (Int) async -> Void
    /// 저장을 지운다(완성했을 때, 새 판을 시작할 때).
    let clearSave: () -> Void
    /// 판 바로 위 왼쪽 '처음부터 다시'를 누르면(게임마다 확인을 묻고 처음 상태로 돌린다).
    var onStartOver: (() -> Void)? = nil
    /// 되돌릴 것이 있을 때만 누를 수 있다.
    var canStartOver = false
    /// 완성 창에 보일 한 줄(거울네모·스위치네모의 조작 횟수).
    var resultNote: (() -> String?)? = nil
    @ViewBuilder let board: () -> Board
    /// 판 바로 아래의 상태 줄과 안내.
    @ViewBuilder let status: () -> Status
    /// 화면 맨 아래의 버튼들.
    @ViewBuilder let controls: () -> Controls
    @ViewBuilder let extraMenu: () -> ExtraMenu
    /// 게임마다 더 겹쳐 보일 창(스위치네모 지옥 실패 안내 등). 인자는 새 퍼즐을 시작하는 동작.
    @ViewBuilder let extraOverlay: (_ newPuzzle: @escaping (Int) -> Void) -> Extra

    @State private var generating: Int?
    @State private var showLevels = false
    @State private var isPaused = false
    @State private var showResult = false
    @State private var showRules = false
    @State private var confirmNew = false
    @State private var didStart = false
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    private var lastLevelKey: String { "\(kind.rawValue).lastLevel" }
    private var lastLevel: Int {
        let v = UserDefaults.standard.integer(forKey: lastLevelKey)
        return levels.contains { $0.id == v } ? v : (levels.first?.id ?? 1)
    }

    private func level(_ id: Int?) -> PuzzleLevelInfo? { levels.first { $0.id == id } }

    var body: some View {
        VStack(spacing: 12) {
            PuzzleTopBar(kind: kind,
                         subtitle: game.status == .empty ? "" : subtitle,
                         showTimer: showTimer,
                         isPlaying: game.status == .playing && !game.isLocked,
                         elapsed: game.elapsed(at:),
                         onBack: { dismiss() },
                         onPause: pauseGame,
                         onNew: newTapped) { menu }
                .id(language)
            // 상단 바 바로 아래 왼쪽. 판은 그 아래 남은 공간의 가운데에 놓인다.
            if let onStartOver {
                StartOverButton(enabled: game.status == .playing && canStartOver, action: onStartOver)
                    .frame(maxWidth: 560)
            }
            // 판과 상태 줄이 남는 공간을 모두 쓰고 그 안에서 가운데에 놓인다.
            // 판이 먼저 공간을 가져가 화면 폭과 남은 높이에 맞춰 최대한 크게 그려진다.
            VStack(spacing: 10) {
                board()
                    .frame(maxWidth: 560)
                    .opacity(game.status == .empty ? 0.35 : 1)
                    .layoutPriority(1)
                status()
                    .frame(maxWidth: 560)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls()
                .frame(maxWidth: 560)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(Paper.bg).ignoresSafeArea())
        .foregroundStyle(Color(Paper.ink))
        .overlay { overlay }
        .animation(.easeOut(duration: 0.2), value: isPaused)
        .animation(.easeOut(duration: 0.2), value: showResult)
        .animation(.easeOut(duration: 0.2), value: showLevels)
        .animation(.easeOut(duration: 0.2), value: generating)
        .animation(.easeOut(duration: 0.2), value: showRules)
        .onAppear {
            guard !didStart else { return }
            didStart = true
            // 처음 들어온 게임이면 규칙부터 보여주고, 닫은 뒤에 이어하기나 난이도 고르기로 간다.
            if RulesSeen.check(kind) { begin() } else { showRules = true }
        }
        .onChange(of: game.status) { _, status in
            guard status == .won else { return }
            clearSave()
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                if game.status == .won { showResult = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if !isPaused && !showLevels && !showRules && !confirmNew { game.resume() }
            } else {
                game.pause()
                game.save()
                if game.status == .playing && !game.isLocked { isPaused = true }
            }
        }
        .onChange(of: showLevels || showRules || confirmNew) { _, open in
            if open { game.pause() } else if !isPaused { game.resume() }
        }
        .onDisappear {
            game.pause()
            game.save()
        }
        .alert("새 게임을 시작할까요?", isPresented: $confirmNew) {
            Button("취소", role: .cancel) {}
            Button("새 퍼즐", role: .destructive) { newPuzzle(game.levelID ?? lastLevel) }
        } message: {
            Text("지금 하던 게임은 사라져요.")
        }
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
    }

    @ViewBuilder private var menu: some View {
        Section("새 퍼즐") {
            ForEach(levels) { info in
                Button(info.menuLabel ?? "\(tr(info.name)) · \(info.detail)") { newPuzzle(info.id) }
            }
        }
        extraMenu()
        Divider()
        Button { showRules = true } label: {
            Label("규칙 보기", systemImage: "questionmark.circle")
        }
    }

    @ViewBuilder private var overlay: some View {
        let time = showTimer ? clock(Int(game.elapsed(at: .now).rounded())) : nil
        if showRules {
            RulesCard(kind: kind) {
                showRules = false
                if !RulesSeen.check(kind) {
                    RulesSeen.mark(kind)
                    begin()
                }
            }
            .transition(.opacity)
        } else if let id = generating {
            PuzzleWorkingCard(text: String(localized: "\(tr(level(id)?.name ?? "")) 퍼즐을 만들고 있어요", bundle: AppLanguage.bundle))
                .transition(.opacity)
        } else if showLevels {
            let best = StatsStore.load(kind).bestByDifficulty
            PuzzleLevelPicker(
                items: levels.map { .init(id: $0.id, name: tr($0.name), detail: $0.detail, best: best[$0.name]) },
                current: lastLevel, accent: kind.fill, canCancel: game.status != .empty,
                onPick: { id in showLevels = false; newPuzzle(id) },
                onCancel: { if game.status == .empty { dismiss() } else { showLevels = false } })
            .transition(.opacity)
        } else if isPaused {
            PuzzlePauseCover(subtitle: subtitle, time: time, accent: kind.fill) {
                isPaused = false
                game.resume()
            }
            .transition(.opacity)
        } else if showResult {
            PuzzleResultCard(title: "\(kind.title) 완성", subtitle: subtitle, note: resultNote?(), time: time,
                             isNewBest: game.isNewBest, accent: kind.fill,
                             onClose: { showResult = false },
                             onOtherLevel: { showResult = false; showLevels = true },
                             onAgain: { showResult = false; newPuzzle(game.levelID ?? lastLevel) })
                .transition(.opacity)
        } else {
            extraOverlay { id in newPuzzle(id) }
        }
    }

    /// 상단 '새 퍼즐': 지금 난이도로 새 판. 손댄 판이 있으면 먼저 묻고, 아직 판이 없으면 난이도를 고르게 한다.
    private func newTapped() {
        guard generating == nil else { return }
        guard let id = game.levelID else { showLevels = true; return }
        if game.status == .playing && game.counted { confirmNew = true } else { newPuzzle(id) }
    }

    /// 저장된 판이 있으면 이어서, 없으면 난이도를 고르게 한다.
    private func begin() {
        if !game.restoreSaved() { showLevels = true }
    }

    private func newPuzzle(_ id: Int) {
        guard generating == nil else { return }
        UserDefaults.standard.set(id, forKey: lastLevelKey)
        game.pause()
        generating = id
        Task {
            await makePuzzle(id)
            clearSave()
            game.save()
            generating = nil
            isPaused = false
            showResult = false
        }
    }

    private func pauseGame() {
        guard game.status == .playing, !game.isLocked else { return }
        game.pause()
        game.save()
        isPaused = true
    }
}

/// 판 아래의 상태 줄("별 3/8 · 조작 4회")과 짧은 안내.
struct PuzzleStatusLine: View {
    let parts: [String]
    /// 굵게 보일 칸(최소 횟수 등).
    var bold: Set<Int> = []
    let guide: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { k, part in
                    if k > 0 {
                        Text(verbatim: "  ·  ").foregroundStyle(Color(Paper.inkSoft))
                    }
                    Text(verbatim: part).fontWeight(bold.contains(k) ? .semibold : .regular)
                }
            }
            .font(.subheadline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            Text(verbatim: guide)
                .font(.caption)
                .foregroundStyle(Color(Paper.inkSoft))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}

/// 판 위에 잠깐 떴다 사라지는 안내("고정된 거울이에요").
struct PuzzleNotice: View {
    let text: String?

    var body: some View {
        if let text {
            Text(verbatim: text)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(Paper.bg), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(Paper.rule)))
                .padding(.top, -18)
                .transition(.opacity)
        }
    }
}

/// tr()처럼 현재 언어로 문장을 만든다. 인자가 있는 문장에 쓴다.
func trf(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: AppLanguage.bundle)
}
