import SwiftUI

/// 후토시키 색. 대표 색(더스티 블루)으로 선택을 표시한다.
private enum FutoshikiColors {
    static let cell = UIColor.dynamic(0xfbfaf5, 0x1b1f1a)
    static let related = UIColor.dynamic(0xe9eef5, 0x232a33)
    static let same = UIColor.dynamic(0xd3dcea, 0x334054)
    static let selected = GameKind.futoshiki.fill
    static let line = UIColor.dynamic(0xd9d5c3, 0x343b32)
    static let user = UIColor.dynamic(0x3d67b0, 0x93b2ff)
    static let wrong = UIColor.dynamic(0xc54a38, 0xff8a78)
    static let guide = UIColor.dynamic(0x4d6a94, 0xa9bbd3)
}

struct FutoshikiView: View {
    @State private var game = FutoshikiGame()
    @State private var generating: FutoshikiLevel?
    @State private var showLevels = false
    @State private var isPaused = false
    @State private var showResult = false
    @State private var confirmRestart = false
    @State private var didStart = false
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("futoshiki.showConflicts") private var showConflicts = true
    @AppStorage("futoshiki.showViolations") private var showViolations = true
    @AppStorage("futoshiki.showGuide") private var showGuide = true
    @AppStorage("futoshiki.lastLevel") private var lastLevel = FutoshikiLevel.medium.rawValue
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    private let accent = GameKind.futoshiki.fill

    private var subtitle: String { "\(tr(game.level.name)) · \(game.size)×\(game.size)" }

    var body: some View {
        VStack(spacing: 14) {
            PuzzleTopBar(kind: .futoshiki,
                         subtitle: game.status == .empty ? "" : subtitle,
                         showTimer: showTimer,
                         isPlaying: game.status == .playing,
                         elapsed: game.elapsed(at:),
                         onBack: { dismiss() },
                         onPause: pauseGame) { menu }
                .id(language)
            Spacer(minLength: 0)
            FutoshikiBoard(game: game, showConflicts: showConflicts,
                           showViolations: showViolations, showGuide: showGuide)
                .frame(maxWidth: 560)
                .opacity(game.status == .empty ? 0.35 : 1)
            if showGuide && game.status != .empty {
                HStack(spacing: 6) {
                    Text(verbatim: "2 < 4").font(.caption.monospacedDigit().weight(.semibold))
                    Text("뾰족한 쪽이 더 작은 숫자예요. 세로도 같아요.")
                        .font(.caption)
                }
                .foregroundStyle(Color(Paper.inkSoft))
            }
            Spacer(minLength: 0)
            controls.frame(maxWidth: 560)
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
            if let saved = FutoshikiSave.load(), game.restore(saved) { return }
            showLevels = true
        }
        .onChange(of: game.status) { _, status in
            guard status == .won else { return }
            FutoshikiSave.clear()
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
                FutoshikiSave.save(game.snapshot())
                if game.status == .playing { isPaused = true }
            }
        }
        .onChange(of: showLevels) { _, open in
            if open { game.pause() } else if !isPaused { game.resume() }
        }
        .onDisappear {
            game.pause()
            if game.status == .playing { FutoshikiSave.save(game.snapshot()) }
        }
        .alert("처음부터 다시 풀까요?", isPresented: $confirmRestart) {
            Button("취소", role: .cancel) {}
            Button("다시 풀기", role: .destructive) { game.restart() }
        } message: {
            Text("같은 문제를 처음 상태로 되돌려요.")
        }
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
    }

    @ViewBuilder private var menu: some View {
        Section("새 퍼즐") {
            ForEach(FutoshikiLevel.allCases) { level in
                Button("\(tr(level.name)) · \(level.size)×\(level.size)") { newPuzzle(level) }
            }
        }
        Button { confirmRestart = true } label: {
            Label("처음부터 다시", systemImage: "arrow.counterclockwise")
        }
        .disabled(game.status != .playing)
        Section("표시") {
            Toggle("중복 숫자 표시", isOn: $showConflicts)
            Toggle("부등호 위반 표시", isOn: $showViolations)
            Toggle("부등호 도움말", isOn: $showGuide)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                PuzzleTool(title: "되돌리기", icon: "arrow.uturn.backward") { game.undo() }
                    .disabled(!game.canUndo)
                PuzzleTool(title: "지우기", icon: "eraser") { game.erase() }
                PuzzleTool(title: game.noteMode ? "메모 켜짐" : "메모", icon: "pencil",
                           active: game.noteMode, accent: accent) { game.noteMode.toggle() }
                    .accessibilityValue(game.noteMode ? Text("켜짐") : Text("꺼짐"))
            }
            HStack(spacing: 6) {
                ForEach(1...max(game.size, 1), id: \.self) { d in digitKey(d) }
            }
        }
        .disabled(game.status != .playing)
    }

    private func digitKey(_ d: Int) -> some View {
        let left = game.size - game.placedCount(d)
        let done = left <= 0 && !game.noteMode
        return Button { game.enter(d) } label: {
            VStack(spacing: 1) {
                Text(verbatim: "\(d)")
                    .font(.system(size: 26, weight: game.noteMode ? .regular : .medium))
                    .foregroundStyle(Color(game.noteMode ? Paper.inkSoft : FutoshikiColors.user))
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
        .accessibilityLabel(Text(verbatim: "\(d)"))
        .accessibilityValue(Text("남은 \(max(left, 0))개"))
    }

    @ViewBuilder private var overlay: some View {
        let time = showTimer ? clock(Int(game.elapsed(at: .now).rounded())) : nil
        if let level = generating {
            PuzzleWorkingCard(text: String(localized: "\(tr(level.name)) 퍼즐을 만들고 있어요", bundle: AppLanguage.bundle))
                .transition(.opacity)
        } else if showLevels {
            PuzzleLevelPicker(
                items: FutoshikiLevel.allCases.map { level in
                    .init(id: level.rawValue, name: tr(level.name), detail: "\(level.size)×\(level.size)",
                          best: StatsStore.load(.futoshiki).bestByDifficulty[level.name])
                },
                current: lastLevel, accent: accent, canCancel: game.status != .empty,
                onPick: { id in showLevels = false; newPuzzle(FutoshikiLevel(rawValue: id) ?? .medium) },
                onCancel: { if game.status == .empty { dismiss() } else { showLevels = false } })
            .transition(.opacity)
        } else if isPaused {
            PuzzlePauseCover(subtitle: subtitle, time: time, accent: accent) {
                isPaused = false
                game.resume()
            }
            .transition(.opacity)
        } else if showResult {
            PuzzleResultCard(title: "\(GameKind.futoshiki.title) 완성", subtitle: subtitle, time: time,
                             isNewBest: game.isNewBest, accent: accent,
                             onClose: { showResult = false },
                             onOtherLevel: { showResult = false; showLevels = true },
                             onAgain: { showResult = false; newPuzzle(game.level) })
                .transition(.opacity)
        }
    }

    private func newPuzzle(_ level: FutoshikiLevel) {
        guard generating == nil else { return }
        lastLevel = level.rawValue
        game.pause()
        generating = level
        Task {
            let puzzle = await Task.detached(priority: .userInitiated) {
                var rng = SystemRandomNumberGenerator()
                return FutoshikiEngine.generate(level, using: &rng)
            }.value
            FutoshikiSave.clear()
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

/// 칸 사이에 부등호 자리를 둔 판.
private struct FutoshikiBoard: View {
    let game: FutoshikiGame
    let showConflicts: Bool
    let showViolations: Bool
    let showGuide: Bool

    @State private var boardWidth: CGFloat = 0

    /// 칸 크기 대비 부등호 틈의 비율.
    private static let gapRatio: CGFloat = 0.42

    var body: some View {
        Canvas { ctx, size in
            guard let puzzle = game.puzzle else { return }
            let n = puzzle.size
            let side = min(size.width, size.height)
            let cell = side / (CGFloat(n) + CGFloat(n - 1) * Self.gapRatio)
            let gap = cell * Self.gapRatio
            let step = cell + gap
            let wrong = (showConflicts ? game.conflicts : []).union(showViolations ? game.violations : [])
            let sel = game.selected
            let selValue = sel.map { game.values[$0] } ?? 0

            func rect(_ i: Int) -> CGRect {
                CGRect(x: CGFloat(i % n) * step, y: CGFloat(i / n) * step, width: cell, height: cell)
            }

            for i in 0..<(n * n) {
                var fill = FutoshikiColors.cell
                if let sel {
                    if i == sel { fill = FutoshikiColors.selected }
                    else if selValue != 0 && game.values[i] == selValue { fill = FutoshikiColors.same }
                    else if i / n == sel / n || i % n == sel % n { fill = FutoshikiColors.related }
                }
                let shape = Path(roundedRect: rect(i), cornerRadius: cell * 0.14)
                ctx.fill(shape, with: .color(Color(fill)))
                ctx.stroke(shape, with: .color(Color(game.isGiven(i) ? Paper.ink : FutoshikiColors.line)),
                           lineWidth: game.isGiven(i) ? 1.5 : 1)

                let box = rect(i)
                let v = game.values[i]
                if v != 0 {
                    let given = game.isGiven(i)
                    let color = wrong.contains(i) && !given ? FutoshikiColors.wrong : (given ? Paper.ink : FutoshikiColors.user)
                    ctx.draw(Text(verbatim: "\(v)")
                                .font(.system(size: cell * 0.52, weight: given ? .semibold : .regular))
                                .foregroundStyle(Color(color)),
                             at: CGPoint(x: box.midX, y: box.midY))
                } else if game.notes[i] != 0 {
                    let cols = n <= 4 ? 2 : 3
                    let rows = (n + cols - 1) / cols
                    for d in 1...n where game.notes[i] & (1 << UInt16(d)) != 0 {
                        let x = box.minX + box.width * (CGFloat((d - 1) % cols) + 0.5) / CGFloat(cols)
                        let y = box.minY + box.height * (CGFloat((d - 1) / cols) + 0.5) / CGFloat(rows)
                        ctx.draw(Text(verbatim: "\(d)")
                                    .font(.system(size: cell * (n <= 4 ? 0.26 : 0.22), weight: .medium))
                                    .foregroundStyle(Color(selValue == d ? Paper.ink : Paper.inkSoft)),
                                 at: CGPoint(x: x, y: y))
                    }
                }
            }

            // 부등호: 뾰족한 쪽이 작은 칸을 가리키는 꺾쇠.
            let arm = gap * 0.36
            for (s, b) in puzzle.relations {
                let a = rect(s), c = rect(b)
                let center = CGPoint(x: (a.midX + c.midX) / 2, y: (a.midY + c.midY) / 2)
                let dx = (a.midX - c.midX) == 0 ? 0 : (a.midX < c.midX ? -1.0 : 1.0)
                let dy = (a.midY - c.midY) == 0 ? 0 : (a.midY < c.midY ? -1.0 : 1.0)
                var path = Path()
                if dx != 0 {
                    // 가로: 꼭짓점이 작은 칸 쪽.
                    path.move(to: CGPoint(x: center.x - dx * arm, y: center.y - arm * 1.1))
                    path.addLine(to: CGPoint(x: center.x + dx * arm, y: center.y))
                    path.addLine(to: CGPoint(x: center.x - dx * arm, y: center.y + arm * 1.1))
                } else {
                    // 세로: 꼭짓점이 작은 칸 쪽.
                    path.move(to: CGPoint(x: center.x - arm * 1.1, y: center.y - dy * arm))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + dy * arm))
                    path.addLine(to: CGPoint(x: center.x + arm * 1.1, y: center.y - dy * arm))
                }
                let broken = showViolations && game.values[s] != 0 && game.values[b] != 0 && game.values[s] >= game.values[b]
                let near = showGuide && (sel == s || sel == b)
                let color = broken ? FutoshikiColors.wrong : (near ? FutoshikiColors.guide : Paper.ink)
                ctx.stroke(path, with: .color(Color(color)),
                           style: StrokeStyle(lineWidth: near || broken ? 3 : 2.2, lineCap: .round, lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { boardWidth = min(geo.size.width, geo.size.height) }
                    .onChange(of: geo.size) { _, s in boardWidth = min(s.width, s.height) }
            }
        }
        .onTapGesture(coordinateSpace: .local) { point in select(at: point) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(GameKind.futoshiki.title) 판")
        .accessibilityValue(Text("\(Int((game.progress * 100).rounded()))% 채움"))
    }

    private func select(at point: CGPoint) {
        guard game.status == .playing, boardWidth > 0 else { return }
        let n = game.size
        let cell = boardWidth / (CGFloat(n) + CGFloat(n - 1) * Self.gapRatio)
        let step = cell * (1 + Self.gapRatio)
        // 틈을 누르면 가까운 칸으로 본다.
        let c = min(max(Int((point.x + cell * Self.gapRatio / 2) / step), 0), n - 1)
        let r = min(max(Int((point.y + cell * Self.gapRatio / 2) / step), 0), n - 1)
        let i = r * n + c
        game.selected = game.selected == i ? nil : i
    }
}
