import SwiftUI

struct ContentView: View {
    private let device = DeviceClass.current
    @State private var game: Game
    @State private var mode: TapMode = .open
    @State private var showSettings = false
    @State private var showResult = false
    @State private var boardSize: CGSize = .zero
    @State private var didStart = false
    @State private var pendingResume: GameSnapshot?
    @State private var isPaused = false
    @State private var confirmRestart = false
    @State private var toast: String?
    @State private var toastID = UUID()
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    init() {
        _game = State(initialValue: Game(config: DeviceClass.current.resolve(Persist.lastConfig)))
    }

    var body: some View {
        VStack(spacing: 10) {
            TopPanel(game: game,
                     showTimer: showTimer,
                     mode: $mode,
                     canSave: game.status == .playing && pendingResume == nil,
                     onBack: { dismiss() },
                     onRestart: askRestart,
                     onPause: pauseGame,
                     onSave: saveNow,
                     onSettings: { showSettings = true })
            // tr()로 옮긴 문구(난이도 이름 등)도 언어가 바뀌면 다시 그린다.
            .id(language)
            GeometryReader { geo in
                BoardView(game: game, version: game.version, skinVersion: SkinStore.shared.version,
                          fitPitch: device.fitPitch) { i, alternate in
                    let wasReady = game.status == .ready
                    Haptics.play(game.act(on: i, alternate: alternate, mode: mode))
                    // 첫 수를 둔 순간 한 판으로 센다.
                    if wasReady && game.status != .ready { StatsStore.recordStart(.minesweeper) }
                }
                .onAppear {
                    boardSize = geo.size
                    if !didStart {
                        didStart = true
                        if let saved = SaveStore.load() { pendingResume = saved } else { start(game.config) }
                    }
                }
                .onChange(of: geo.size) { _, size in boardSize = size }
            }
            ProgressFooter(game: game)
                .id(language)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: 1600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(Palette.bg).ignoresSafeArea())
        .foregroundStyle(Color(Palette.ink))
        .overlay {
            if let saved = pendingResume {
                ResumeCard(snapshot: saved, showTimer: showTimer, onNew: {
                    pendingResume = nil
                    start(game.config)
                }, onResume: {
                    pendingResume = nil
                    if game.restore(saved) { Persist.lastConfig = saved.config } else { start(game.config) }
                })
                .transition(.opacity)
            } else if isPaused {
                PauseCard(game: game, showTimer: showTimer, onNew: restart, onResume: resumeGame)
                    .transition(.opacity)
            } else if showResult {
                ResultCard(game: game, showTimer: showTimer, onView: { showResult = false }, onAgain: restart)
                    .transition(.opacity)
            }
        }
        // 펜슬을 쥐거나 두 번 탭하면 열기 ↔ 깃발. 물음표 모드에서는 열기로 돌아간다.
        .onPencilModeSwitch {
            mode = mode == .open ? .flag : .open
        }
        .animation(.easeOut(duration: 0.2), value: showResult)
        .animation(.easeOut(duration: 0.2), value: isPaused)
        .overlay(alignment: .bottom) {
            if let toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(Palette.onMoss))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color(Palette.moss), in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(current: game.config, device: device) { config in
                showSettings = false
                start(config)
            }
        }
        .onChange(of: game.status) { _, status in
            guard status == .won || status == .lost else { return }
            SaveStore.clear()
            if status == .won {
                StatsStore.recordWin(.minesweeper, difficulty: game.config.name,
                                     seconds: Int(game.elapsed(at: .now).rounded()))
            }
            let generation = game.generation
            Task {
                try? await Task.sleep(for: .milliseconds(status == .won ? 400 : 800))
                if game.generation == generation { showResult = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // 이어하기를 묻는 중에는 저장된 게임을 건드리지 않는다.
            guard pendingResume == nil else { return }
            if phase == .active {
                if !isPaused && !showSettings { game.resume() }
            } else {
                game.pause()
                SaveStore.save(game.snapshot())
                // 돌아오면 일시정지 화면에서 계속하기를 눌러야 다시 시작된다.
                if game.status == .playing { isPaused = true }
            }
        }
        // 메인 화면으로 돌아가면 하던 게임을 저장해 두고, 다시 들어오면 이어하기를 묻는다.
        .onDisappear {
            guard pendingResume == nil, game.status == .playing else { return }
            game.pause()
            SaveStore.save(game.snapshot())
        }
        .alert("새 게임을 시작할까요?", isPresented: $confirmRestart) {
            Button("취소", role: .cancel) {}
            Button("새 게임", role: .destructive, action: restart)
        } message: {
            Text("지금 하던 게임은 사라져요.")
        }
        .onChange(of: confirmRestart) { _, open in
            if open { game.pause() } else if !isPaused && !showSettings { game.resume() }
        }
        .onChange(of: showSettings) { _, open in
            // 설정을 보는 동안은 시간을 멈춘다.
            if open { game.pause() } else if !isPaused { game.resume() }
        }
        // 메인 화면, 일시정지·결과·이어하기 창, 확인 창, 설정 시트까지 모두 고른 언어를 따른다.
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
    }

    private func start(_ config: BoardConfig) {
        SaveStore.clear()
        showResult = false
        isPaused = false
        game.reset(config: config, portrait: boardSize.height >= boardSize.width)
        Persist.lastConfig = config
    }

    private func restart() { start(game.config) }

    /// 진행 중인 게임이 있으면 지우기 전에 묻는다.
    private func askRestart() {
        if game.status == .playing { confirmRestart = true } else { restart() }
    }

    private func pauseGame() {
        guard game.status == .playing else { return }
        game.pause()
        isPaused = true
    }

    private func resumeGame() {
        isPaused = false
        game.resume()
    }

    private func saveNow() {
        guard let snapshot = game.snapshot() else { return }
        SaveStore.save(snapshot)
        Haptics.play(.flag)
        let id = UUID()
        toastID = id
        withAnimation(.spring(duration: 0.3)) { toast = tr("저장했어요. 다음에 열면 이어서 할 수 있어요") }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toastID == id { withAnimation(.easeOut(duration: 0.25)) { toast = nil } }
        }
    }
}

/// 상단 패널: 이름·난이도, 열기/깃발, 남은 지뢰, 시간, 새 게임, 일시정지, 더보기(저장·설정).
struct TopPanel: View {
    let game: Game
    let showTimer: Bool
    @Binding var mode: TapMode
    let canSave: Bool
    let onBack: () -> Void
    let onRestart: () -> Void
    let onPause: () -> Void
    let onSave: () -> Void
    let onSettings: () -> Void

    /// 한 줄에 다 들어가면 한 줄(iPad 가로·세로, 가로로 눕힌 iPhone), 모자라면 두 줄.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                backButton
                brand.fixedSize()
                modeToggle
                Spacer(minLength: 16)
                stats
                restartButton.padding(.leading, 8)
                pauseButton
                moreMenu
            }

            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    backButton
                    brand.layoutPriority(1)
                    Spacer(minLength: 0)
                    stats
                    moreMenu
                }
                HStack(spacing: 6) {
                    modeToggle
                    // 새 게임 버튼을 실수로 누르지 않도록 오른쪽 끝으로 민다.
                    Spacer(minLength: 14)
                    restartButton
                    pauseButton
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(Palette.well), in: RoundedRectangle(cornerRadius: 18))
    }

    private var brand: some View {
        HStack(spacing: 8) {
            GameSymbol(kind: .minesweeper, size: 20, color: Color(Palette.ink))
            brandText
        }
    }

    private var brandText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: GameKind.minesweeper.title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            Text("\(tr(game.config.name)) · \(game.cols)×\(game.rows)")
                .font(.caption2)
                .foregroundStyle(Color(Palette.inkSoft))
                .lineLimit(1)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("flag", pad3(game.minesLeft))
                .accessibilityLabel("남은 지뢰 \(game.minesLeft)개")
            if showTimer {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let seconds = Int(game.elapsed(at: context.date))
                    stat("stopwatch", pad3(seconds))
                        .accessibilityLabel("시간 \(seconds)초")
                }
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Button(action: onSave) { Label("저장", systemImage: "square.and.arrow.down") }
                .disabled(!canSave)
            Button(action: onSettings) { Label("설정", systemImage: "slider.horizontal.3") }
        } label: {
            square(Image(systemName: "ellipsis"))
        }
        .accessibilityLabel("더보기")
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("열기", icon: "square.dashed", mode: .open)
            modeButton("깃발", icon: "flag", mode: .flag)
            modeButton(nil, icon: "questionmark", mode: .question)
                .accessibilityLabel("물음표")
        }
        .padding(2)
        .background(Color(Palette.raised), in: RoundedRectangle(cornerRadius: 11))
        .fixedSize()
    }

    private var backButton: some View {
        Button(action: onBack) { square(Image(systemName: "chevron.left")) }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            square(Image(systemName: "arrow.counterclockwise"), fill: restartFill,
                   ink: game.status == .won ? Palette.onMoss : Palette.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 게임")
    }

    private var pauseButton: some View {
        Button(action: onPause) { square(Image(systemName: "pause.circle")) }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
            .accessibilityLabel("일시정지")
    }

    private var restartFill: UIColor {
        switch game.status {
        case .won: Palette.moss
        case .lost: Palette.hit
        default: Palette.raised
        }
    }

    private func stat(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(Palette.inkSoft))
            Text(value)
                .font(.system(size: 19, weight: .medium))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
    }

    private func square(_ image: Image, fill: UIColor = Palette.raised, ink: UIColor = Palette.ink) -> some View {
        image
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color(ink))
            .frame(width: 44, height: 38)
            .background(Color(fill), in: RoundedRectangle(cornerRadius: 11))
    }

    /// title이 없으면 아이콘만 보여준다.
    private func modeButton(_ title: LocalizedStringKey?, icon: String, mode value: TapMode) -> some View {
        let selected = mode == value
        return Button {
            mode = value
        } label: {
            Group {
                if let title { Label(title, systemImage: icon) } else { Image(systemName: icon) }
            }
                .font(.system(.subheadline, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(Color(selected ? Palette.onMoss : Palette.inkSoft))
                .background(selected ? Color(Palette.moss) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 안전한 칸을 얼마나 열었는지. 이기려면 안전한 칸을 모두 열어야 한다.
struct ProgressFooter: View {
    let game: Game

    var body: some View {
        let safe = max(1, game.cols * game.rows - game.mines)
        let left = game.safeLeft
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(Palette.line))
                    Capsule().fill(Color(Paper.ink))
                        .frame(width: geo.size.width * CGFloat(safe - left) / CGFloat(safe))
                }
            }
            .frame(height: 3)
            Text("남은 칸 \(left)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Color(Palette.inkSoft))
        }
        .padding(.horizontal, 4)
        .animation(.easeOut(duration: 0.25), value: left)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("남은 안전한 칸 \(left)개")
    }
}

/// 보드를 가려서 멈춘 동안 칸을 보며 생각할 수 없게 한다.
struct PauseCard: View {
    let game: Game
    let showTimer: Bool
    let onNew: () -> Void
    let onResume: () -> Void

    var body: some View {
        ZStack {
            Color(Palette.bg).opacity(0.97).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(Palette.moss))
                Text("일시정지")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Text("\(tr(game.config.name)) · \(game.cols)×\(game.rows) · 지뢰 \(game.mines)")
                    .font(.subheadline)
                    .foregroundStyle(Color(Palette.inkSoft))
                if showTimer {
                    Text(clock(Int(game.elapsed(at: .now))))
                        .font(.system(size: 32, weight: .medium, design: .monospaced))
                }
                HStack(spacing: 8) {
                    Button(action: onNew) { Text("새 게임").frame(maxWidth: .infinity) }
                        .buttonStyle(FieldButtonStyle())
                    Button(action: onResume) { Text("계속하기").frame(maxWidth: .infinity) }
                        .buttonStyle(FieldButtonStyle(prominent: true))
                }
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 360)
        }
    }
}

struct ResumeCard: View {
    let snapshot: GameSnapshot
    let showTimer: Bool
    let onNew: () -> Void
    let onResume: () -> Void

    var body: some View {
        let c = snapshot.config
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("지난 게임이 있어요")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Text("\(tr(c.name)) · \(snapshot.cols)×\(snapshot.rows) · 지뢰 \(c.mines)")
                    .font(.subheadline)
                VStack(spacing: 6) {
                    ProgressView(value: snapshot.progress)
                        .tint(Color(Palette.moss))
                    HStack {
                        Text("\(Int((snapshot.progress * 100).rounded()))% 진행")
                        Spacer()
                        if showTimer { Text(clock(Int(snapshot.elapsed))) }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(Palette.inkSoft))
                }
                Text("\(snapshot.savedAt.formatted(.relative(presentation: .named).locale(AppLanguage.locale))) 저장됨")
                    .font(.caption)
                    .foregroundStyle(Color(Palette.inkSoft))
                HStack(spacing: 8) {
                    Button(action: onNew) { Text("새 게임").frame(maxWidth: .infinity) }
                        .buttonStyle(FieldButtonStyle())
                    Button(action: onResume) { Text("이어하기").frame(maxWidth: .infinity) }
                        .buttonStyle(FieldButtonStyle(prominent: true))
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(Palette.panel), in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
    }
}

struct ResultCard: View {
    let game: Game
    let showTimer: Bool
    let onView: () -> Void
    let onAgain: () -> Void

    var body: some View {
        let won = game.status == .won
        let seconds = Int(game.elapsed(at: .now).rounded())
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: onView)
            VStack(spacing: 12) {
                Text(won ? LocalizedStringKey("지뢰 제거 완료") : LocalizedStringKey("펑, 지뢰를 밟았어요"))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                if showTimer {
                    Text(clock(seconds))
                        .font(.system(size: 44, weight: .medium, design: .monospaced))
                }
                if showTimer && won && game.isNewBest {
                    Text("최고 기록")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(Color(Palette.onMoss))
                        .background(Color(Palette.moss), in: Capsule())
                }
                Text(subtitle(won: won))
                    .font(.subheadline)
                    .foregroundStyle(Color(Palette.inkSoft))
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button(action: onView) { Text("보드 보기").frame(maxWidth: .infinity) }
                        .buttonStyle(FieldButtonStyle())
                    Button(action: onAgain) { Text("다시 하기").frame(maxWidth: .infinity) }
                        .buttonStyle(FieldButtonStyle(prominent: true))
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(Palette.panel), in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
    }

    private func subtitle(won: Bool) -> String {
        guard won else { return String(localized: "안전한 칸 \(game.safeLeft)개가 남아 있었어요", bundle: AppLanguage.bundle) }
        guard showTimer else { return String(localized: "지뢰를 모두 찾았어요", bundle: AppLanguage.bundle) }
        if game.isNewBest { return String(localized: "이 크기에서 가장 빠른 기록이에요", bundle: AppLanguage.bundle) }
        return RecordStore.best(for: game.config.recordKey).map { String(localized: "최고 기록 \(clock($0))", bundle: AppLanguage.bundle) } ?? ""
    }
}
