import SwiftUI

/// 스도쿠 판과 키패드에 쓰는 색. 대표 색(버터 옐로)으로 선택을 표시한다.
private enum SudokuColors {
    static let cell = UIColor.dynamic(0xfbfaf5, 0x1b1f1a)
    static let related = UIColor.dynamic(0xf3efd8, 0x262a20)
    static let same = UIColor.dynamic(0xe6dfb0, 0x48432a)
    static let selected = UIColor.dynamic(0xd6cb85, 0x6b6238)
    static let thin = UIColor.dynamic(0xd9d5c3, 0x343b32)
    static let user = UIColor.dynamic(0x3d67b0, 0x93b2ff)
    static let wrong = UIColor.dynamic(0xc54a38, 0xff8a78)
}

struct SudokuView: View {
    @State private var game = SudokuGame()
    @State private var generating: SudokuLevel?
    @State private var showLevels = false
    @State private var isPaused = false
    @State private var showResult = false
    @State private var confirmRestart = false
    @State private var didStart = false
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("sudoku.showConflicts") private var showConflicts = true
    @AppStorage("sudoku.showMistakes") private var showMistakes = false
    @AppStorage("sudoku.lastLevel") private var lastLevel = SudokuLevel.medium.rawValue
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            topBar
            Spacer(minLength: 0)
            SudokuBoard(game: game, showConflicts: showConflicts, showMistakes: showMistakes)
                .frame(maxWidth: 560)
                .opacity(game.status == .empty ? 0.35 : 1)
            Spacer(minLength: 0)
            controls
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
        .onPencilModeSwitch { game.noteMode.toggle() }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            if let saved = SudokuSave.load(), game.restore(saved) { return }
            showLevels = true
        }
        .onChange(of: game.status) { _, status in
            guard status == .won else { return }
            SudokuSave.clear()
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                if game.status == .won { showResult = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if !isPaused && !showLevels { game.resume() }
            } else {
                game.pause()
                SudokuSave.save(game.snapshot())
                if game.status == .playing { isPaused = true }
            }
        }
        .onChange(of: showLevels) { _, open in
            if open { game.pause() } else if !isPaused { game.resume() }
        }
        .onDisappear {
            game.pause()
            if game.status == .playing { SudokuSave.save(game.snapshot()) }
        }
        .alert("처음부터 다시 풀까요?", isPresented: $confirmRestart) {
            Button("취소", role: .cancel) {}
            Button("다시 풀기", role: .destructive) { game.restart() }
        } message: {
            Text("같은 문제를 처음 상태로 되돌려요.")
        }
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
    }

    // MARK: 상단

    private var topBar: some View {
        HStack(spacing: 12) {
            square("chevron.left", label: "뒤로") { dismiss() }
            VStack(alignment: .leading, spacing: 1) {
                Text("스도쿠")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(game.status == .empty ? "" : tr(game.level.name))
                    .font(.caption2)
                    .foregroundStyle(Color(Paper.inkSoft))
            }
            .id(language)
            Spacer(minLength: 8)
            if showTimer && game.status != .empty {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let seconds = Int(game.elapsed(at: context.date))
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(Paper.inkSoft))
                        Text(verbatim: clock(seconds))
                            .font(.system(size: 19, weight: .medium))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("시간 \(seconds)초")
                }
            }
            square("pause.circle", label: "일시정지") { pauseGame() }
                .disabled(game.status != .playing)
                .opacity(game.status == .playing ? 1 : 0.4)
            menu
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(Paper.sheet), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: 760)
    }

    private var menu: some View {
        Menu {
            Section("새 퍼즐") {
                ForEach(SudokuLevel.allCases) { level in
                    Button(tr(level.name)) { newPuzzle(level) }
                }
            }
            Button { confirmRestart = true } label: {
                Label("처음부터 다시", systemImage: "arrow.counterclockwise")
            }
            .disabled(game.status != .playing)
            Section("표시") {
                Toggle("중복 숫자 표시", isOn: $showConflicts)
                Toggle("틀린 숫자 바로 표시", isOn: $showMistakes)
            }
        } label: {
            squareLabel("ellipsis")
        }
        .accessibilityLabel("더보기")
    }

    // MARK: 하단

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                tool("되돌리기", icon: "arrow.uturn.backward", active: false) { game.undo() }
                    .disabled(!game.canUndo)
                tool("지우기", icon: "eraser", active: false) { game.erase() }
                tool(game.noteMode ? "메모 켜짐" : "메모", icon: "pencil", active: game.noteMode) { game.noteMode.toggle() }
                    .accessibilityValue(game.noteMode ? Text("켜짐") : Text("꺼짐"))
            }
            HStack(spacing: 6) {
                ForEach(1...9, id: \.self) { d in digitKey(d) }
            }
        }
        .disabled(game.status != .playing)
    }

    private func digitKey(_ d: Int) -> some View {
        let left = 9 - game.placedCount(d)
        let done = left <= 0 && !game.noteMode
        return Button { game.enter(d) } label: {
            VStack(spacing: 1) {
                Text(verbatim: "\(d)")
                    .font(.system(size: 26, weight: game.noteMode ? .regular : .medium))
                    .foregroundStyle(Color(game.noteMode ? Paper.inkSoft : SudokuColors.user))
                Text(verbatim: left > 0 ? "\(left)" : " ")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(Paper.inkSoft))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color(Paper.sheet), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(done ? 0.3 : 1)
        .accessibilityLabel("\(d)")
        .accessibilityValue(Text("남은 \(max(left, 0))개"))
    }

    private func tool(_ title: LocalizedStringKey, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(Color(Paper.ink))
            .background(Color(active ? GameKind.sudoku.fill : Paper.sheet), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func square(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) { squareLabel(icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    private func squareLabel(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color(Paper.ink))
            .frame(width: 44, height: 38)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 11))
    }

    // MARK: 겹쳐 보이는 창

    @ViewBuilder private var overlay: some View {
        if let level = generating {
            card {
                ProgressView().tint(Color(Paper.ink))
                Text("\(tr(level.name)) 퍼즐을 만들고 있어요")
                    .font(.subheadline)
            }
        } else if showLevels {
            LevelPicker(current: SudokuLevel(rawValue: lastLevel) ?? .medium,
                        canCancel: game.status != .empty,
                        onPick: { level in showLevels = false; newPuzzle(level) },
                        onCancel: { if game.status == .empty { dismiss() } else { showLevels = false } })
                .transition(.opacity)
        } else if isPaused {
            ZStack {
                Color(Paper.bg).opacity(0.97).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color(GameKind.sudoku.fill))
                    Text("일시정지").font(.system(.title2, design: .rounded, weight: .heavy))
                    Text(tr(game.level.name)).font(.subheadline).foregroundStyle(Color(Paper.inkSoft))
                    if showTimer {
                        Text(verbatim: clock(Int(game.elapsed(at: .now))))
                            .font(.system(size: 32, weight: .medium, design: .monospaced))
                    }
                    Button { isPaused = false; game.resume() } label: {
                        Text("계속하기").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaperButtonStyle(prominent: true))
                    .padding(.top, 8)
                }
                .padding(24)
                .frame(maxWidth: 320)
            }
            .transition(.opacity)
        } else if showResult {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { showResult = false }
                VStack(spacing: 12) {
                    Text("스도쿠 완성").font(.system(.title2, design: .rounded, weight: .heavy))
                    Text(tr(game.level.name)).font(.subheadline).foregroundStyle(Color(Paper.inkSoft))
                    if showTimer {
                        Text(verbatim: clock(Int(game.elapsed(at: .now).rounded())))
                            .font(.system(size: 44, weight: .medium, design: .monospaced))
                        if game.isNewBest {
                            Text("최고 기록")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(GameKind.sudoku.fill), in: Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Button { showResult = false; showLevels = true } label: {
                            Text("다른 난이도").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PaperButtonStyle())
                        Button { showResult = false; newPuzzle(game.level) } label: {
                            Text("새 퍼즐").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PaperButtonStyle(prominent: true))
                    }
                    .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: 360)
                .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 22))
                .padding(24)
            }
            .transition(.opacity)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14, content: content)
                .padding(24)
                .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 18))
        }
        .transition(.opacity)
    }

    // MARK: 동작

    private func newPuzzle(_ level: SudokuLevel) {
        guard generating == nil else { return }
        lastLevel = level.rawValue
        game.pause()
        generating = level
        Task {
            // 고급은 만드는 데 1초 가까이 걸릴 수 있어 화면이 멈추지 않도록 따로 돌린다.
            let puzzle = await Task.detached(priority: .userInitiated) {
                var rng = SystemRandomNumberGenerator()
                return SudokuEngine.generate(level, using: &rng)
            }.value
            SudokuSave.clear()
            game.start(puzzle)
            generating = nil
            isPaused = false
            showResult = false
        }
    }

    private func pauseGame() {
        guard game.status == .playing else { return }
        game.pause()
        isPaused = true
    }
}

/// 81칸을 한 번에 그린다. 탭한 위치로 칸을 고른다.
private struct SudokuBoard: View {
    let game: SudokuGame
    let showConflicts: Bool
    let showMistakes: Bool

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let cell = side / 9
            let wrong = (showConflicts ? game.conflicts : []).union(showMistakes ? game.mistakes : [])
            let sel = game.selected
            let selValue = sel.map { game.values[$0] } ?? 0

            for i in 0..<81 {
                let rect = CGRect(x: CGFloat(i % 9) * cell, y: CGFloat(i / 9) * cell, width: cell, height: cell)
                var fill = SudokuColors.cell
                if let sel {
                    if i == sel { fill = SudokuColors.selected }
                    else if selValue != 0 && game.values[i] == selValue { fill = SudokuColors.same }
                    else if i / 9 == sel / 9 || i % 9 == sel % 9 || SudokuGrid.box(i) == SudokuGrid.box(sel) { fill = SudokuColors.related }
                }
                ctx.fill(Path(rect), with: .color(Color(fill)))

                let v = game.values[i]
                if v != 0 {
                    let given = game.isGiven(i)
                    let color = wrong.contains(i) && !given ? SudokuColors.wrong : (given ? Paper.ink : SudokuColors.user)
                    ctx.draw(Text(verbatim: "\(v)")
                                .font(.system(size: cell * 0.56, weight: given ? .semibold : .regular))
                                .foregroundStyle(Color(color)),
                             at: CGPoint(x: rect.midX, y: rect.midY))
                } else if game.notes[i] != 0 {
                    for d in 1...9 where game.notes[i] & (1 << UInt16(d)) != 0 {
                        let x = rect.minX + cell * (CGFloat((d - 1) % 3) + 0.5) / 3
                        let y = rect.minY + cell * (CGFloat((d - 1) / 3) + 0.5) / 3
                        ctx.draw(Text(verbatim: "\(d)")
                                    .font(.system(size: cell * 0.24, weight: .medium))
                                    .foregroundStyle(Color(selValue == d ? Paper.ink : Paper.inkSoft)),
                                 at: CGPoint(x: x, y: y))
                    }
                }
            }

            for k in 1..<9 where k % 3 != 0 {
                let p = CGFloat(k) * cell
                var path = Path()
                path.move(to: CGPoint(x: p, y: 0)); path.addLine(to: CGPoint(x: p, y: side))
                path.move(to: CGPoint(x: 0, y: p)); path.addLine(to: CGPoint(x: side, y: p))
                ctx.stroke(path, with: .color(Color(SudokuColors.thin)), lineWidth: 1)
            }
            var thick = Path()
            for k in [3, 6] {
                let p = CGFloat(k) * cell
                thick.move(to: CGPoint(x: p, y: 0)); thick.addLine(to: CGPoint(x: p, y: side))
                thick.move(to: CGPoint(x: 0, y: p)); thick.addLine(to: CGPoint(x: side, y: p))
            }
            ctx.stroke(thick, with: .color(Color(Paper.ink)), lineWidth: 2)
            ctx.stroke(Path(roundedRect: CGRect(x: 1, y: 1, width: side - 2, height: side - 2), cornerRadius: 6),
                       with: .color(Color(Paper.ink)), lineWidth: 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { boardWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in boardWidth = w }
            }
        }
        .onTapGesture(coordinateSpace: .local) { point in select(at: point) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("스도쿠 판")
        .accessibilityValue(Text("\(Int((game.progress * 100).rounded()))% 채움"))
    }

    private func select(at point: CGPoint) {
        guard game.status == .playing else { return }
        // Canvas는 정사각형이므로 폭으로 칸 크기를 구한다.
        let width = boardWidth
        guard width > 0 else { return }
        let cell = width / 9
        let c = Int(point.x / cell), r = Int(point.y / cell)
        guard (0..<9).contains(c), (0..<9).contains(r) else { return }
        let i = r * 9 + c
        game.selected = game.selected == i ? nil : i
    }

    @State private var boardWidth: CGFloat = 0
}

/// 난이도 고르기. 기획서의 기준(필요한 풀이 기법)을 짧게 보여준다.
private struct LevelPicker: View {
    let current: SudokuLevel
    let canCancel: Bool
    let onPick: (SudokuLevel) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("난이도를 골라 주세요")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                VStack(spacing: 8) {
                    ForEach(SudokuLevel.allCases) { level in
                        Button { onPick(level) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tr(level.name)).font(.subheadline.weight(.semibold))
                                    Text(tr(Self.detail(level))).font(.caption).foregroundStyle(Color(Paper.inkSoft))
                                }
                                Spacer()
                                if let best = StatsStore.load(.sudoku).bestByDifficulty[level.name] {
                                    Text(verbatim: clock(best)).font(.caption.monospacedDigit()).foregroundStyle(Color(Paper.inkSoft))
                                }
                            }
                            .padding(14)
                            .background(Color(level == current ? GameKind.sudoku.fill : Paper.sheet), in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(canCancel ? "취소" : "돌아가기", action: onCancel)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .padding(22)
            .frame(maxWidth: 380)
            .background(Color(Paper.bg), in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
    }

    static func detail(_ level: SudokuLevel) -> String {
        switch level {
        case .easy: "기본적인 행·열·구역 제외법"
        case .medium: "숫자 후보 비교"
        case .hard: "여러 후보의 연쇄 추론"
        case .expert: "복잡한 후보 조합과 고급 논리 기법"
        }
    }
}

struct PaperButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(Color(prominent ? Paper.bg : Paper.ink))
            .background(Color(prominent ? Paper.ink : Paper.sheet), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
