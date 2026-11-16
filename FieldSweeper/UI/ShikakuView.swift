import SwiftUI

private enum ShikakuColors {
    static let cell = UIColor.dynamic(0xfbfaf5, 0x1b1f1a)
    static let thin = UIColor.dynamic(0xdedacb, 0x343b32)
    /// 영역 색(기획서 2.4 추천 색). 맞닿은 영역끼리는 다른 색을 쓴다.
    static let regions: [UIColor] = [
        .dynamic(0xd7e4ce, 0x2e3a2c), // Sage Green
        .dynamic(0xdce4f0, 0x2c3442), // Dusty Blue
        .dynamic(0xf1dccb, 0x42342a), // Apricot
        .dynamic(0xf0e6bc, 0x3e3824), // Butter Yellow
        .dynamic(0xe4deee, 0x363244), // Muted Lilac
        .dynamic(0xd9e9de, 0x2b3a31), // Soft Mint
    ]
}

struct ShikakuView: View {
    @State private var game = ShikakuGame()
    @State private var generating: ShikakuLevel?
    @State private var showLevels = false
    @State private var isPaused = false
    @State private var showResult = false
    @State private var confirmRestart = false
    @State private var confirmClear = false
    @State private var didStart = false
    @State private var notice: String?
    @State private var noticeID = UUID()
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("shikaku.lastLevel") private var lastLevel = ShikakuLevel.medium.rawValue
    @AppStorage(AppLanguage.storageKey) private var language = "system"
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    private let accent = GameKind.shikaku.fill

    var body: some View {
        VStack(spacing: 14) {
            PuzzleTopBar(title: "시카쿠",
                         subtitle: game.status == .empty ? "" : "\(tr(game.level.name)) · \(game.size)×\(game.size)",
                         showTimer: showTimer,
                         isPlaying: game.status == .playing,
                         elapsed: game.elapsed(at:),
                         onBack: { dismiss() },
                         onPause: pauseGame) { menu }
                .id(language)
            Spacer(minLength: 0)
            ShikakuBoard(game: game, accent: accent) { problem in show(problem) }
                .frame(maxWidth: 600)
                .opacity(game.status == .empty ? 0.35 : 1)
                .overlay(alignment: .top) {
                    if let notice {
                        Text(verbatim: notice)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color(Paper.bg), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color(Paper.rule)))
                            .padding(.top, -18)
                            .transition(.opacity)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                PuzzleTool(title: "되돌리기", icon: "arrow.uturn.backward") { game.undo() }
                    .disabled(!game.canUndo)
                PuzzleTool(title: "지우기", icon: "eraser", active: game.selected != nil, accent: accent) { game.removeSelected() }
                    .disabled(game.selected == nil)
                PuzzleTool(title: "전체 지우기", icon: "trash") { confirmClear = true }
                    .disabled(game.regions.isEmpty)
            }
            .disabled(game.status != .playing)
            .frame(maxWidth: 600)
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
        .animation(.easeOut(duration: 0.2), value: notice)
        .onAppear {
            guard !didStart else { return }
            didStart = true
            if let saved = ShikakuSave.load(), game.restore(saved) { return }
            showLevels = true
        }
        .onChange(of: game.status) { _, status in
            guard status == .won else { return }
            ShikakuSave.clear()
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
                ShikakuSave.save(game.snapshot())
                if game.status == .playing { isPaused = true }
            }
        }
        .onChange(of: showLevels) { _, open in
            if open { game.pause() } else if !isPaused { game.resume() }
        }
        .onDisappear {
            game.pause()
            if game.status == .playing { ShikakuSave.save(game.snapshot()) }
        }
        .alert("처음부터 다시 풀까요?", isPresented: $confirmRestart) {
            Button("취소", role: .cancel) {}
            Button("다시 풀기", role: .destructive) { game.restart() }
        } message: {
            Text("같은 문제를 처음 상태로 되돌려요.")
        }
        .alert("영역을 모두 지울까요?", isPresented: $confirmClear) {
            Button("취소", role: .cancel) {}
            Button("모두 지우기", role: .destructive) { game.clearAll() }
        } message: {
            Text("되돌리기로 다시 살릴 수 있어요.")
        }
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
    }

    @ViewBuilder private var menu: some View {
        Section("새 퍼즐") {
            ForEach(ShikakuLevel.allCases) { level in
                Button("\(tr(level.name)) · \(level.size)×\(level.size)") { newPuzzle(level) }
            }
        }
        Button { confirmRestart = true } label: {
            Label("처음부터 다시", systemImage: "arrow.counterclockwise")
        }
        .disabled(game.status != .playing)
    }

    @ViewBuilder private var overlay: some View {
        let time = showTimer ? clock(Int(game.elapsed(at: .now).rounded())) : nil
        let subtitle = "\(tr(game.level.name)) · \(game.size)×\(game.size)"
        if let level = generating {
            PuzzleWorkingCard(text: String(localized: "\(tr(level.name)) 퍼즐을 만들고 있어요", bundle: AppLanguage.bundle))
                .transition(.opacity)
        } else if showLevels {
            PuzzleLevelPicker(
                items: ShikakuLevel.allCases.map { level in
                    .init(id: level.rawValue, name: tr(level.name), detail: "\(level.size)×\(level.size)",
                          best: StatsStore.load(.shikaku).bestByDifficulty[level.name])
                },
                current: lastLevel, accent: accent, canCancel: game.status != .empty,
                onPick: { id in showLevels = false; newPuzzle(ShikakuLevel(rawValue: id) ?? .medium) },
                onCancel: { if game.status == .empty { dismiss() } else { showLevels = false } })
            .transition(.opacity)
        } else if isPaused {
            PuzzlePauseCover(subtitle: subtitle, time: time, accent: accent) {
                isPaused = false
                game.resume()
            }
            .transition(.opacity)
        } else if showResult {
            PuzzleResultCard(title: "시카쿠 완성", subtitle: subtitle, time: time,
                             isNewBest: game.isNewBest, accent: accent,
                             onClose: { showResult = false },
                             onOtherLevel: { showResult = false; showLevels = true },
                             onAgain: { showResult = false; newPuzzle(game.level) })
                .transition(.opacity)
        }
    }

    private func show(_ problem: ShikakuGame.Problem) {
        let text: String
        switch problem {
        case .noClue: text = String(localized: "영역 안에 숫자가 하나 있어야 해요", bundle: AppLanguage.bundle)
        case .manyClues: text = String(localized: "영역 안에 숫자는 하나만 들어가야 해요", bundle: AppLanguage.bundle)
        case .wrongArea(let need, let got): text = String(localized: "\(need)칸이 필요해요. 지금은 \(got)칸이에요", bundle: AppLanguage.bundle)
        case .overlap: text = String(localized: "다른 영역과 겹쳐요", bundle: AppLanguage.bundle)
        }
        let id = UUID()
        noticeID = id
        notice = text
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if noticeID == id { notice = nil }
        }
    }

    private func newPuzzle(_ level: ShikakuLevel) {
        guard generating == nil else { return }
        lastLevel = level.rawValue
        game.pause()
        generating = level
        Task {
            let puzzle = await Task.detached(priority: .userInitiated) {
                var rng = SystemRandomNumberGenerator()
                return ShikakuEngine.generate(level, using: &rng)
            }.value
            ShikakuSave.clear()
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

/// 판. 시작 칸에서 끌어 직사각형을 그리고, 손을 떼면 확정한다. 영역을 탭하면 지우기 대상으로 고른다.
private struct ShikakuBoard: View {
    let game: ShikakuGame
    let accent: UIColor
    let onProblem: (ShikakuGame.Problem) -> Void

    @State private var dragStart: Int?
    @State private var dragEnd: Int?
    @State private var boardWidth: CGFloat = 0

    private var preview: ShikakuRect? {
        guard let a = dragStart, let b = dragEnd else { return nil }
        return .spanning(a, b, size: game.size)
    }

    var body: some View {
        Canvas { ctx, size in
            let n = game.size
            let side = min(size.width, size.height)
            let cell = side / CGFloat(n)
            func frame(_ r: ShikakuRect) -> CGRect {
                CGRect(x: CGFloat(r.col) * cell, y: CGFloat(r.row) * cell,
                       width: CGFloat(r.width) * cell, height: CGFloat(r.height) * cell)
            }

            ctx.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Color(ShikakuColors.cell)))
            var grid = Path()
            for k in 1..<n {
                let p = CGFloat(k) * cell
                grid.move(to: CGPoint(x: p, y: 0)); grid.addLine(to: CGPoint(x: p, y: side))
                grid.move(to: CGPoint(x: 0, y: p)); grid.addLine(to: CGPoint(x: side, y: p))
            }
            ctx.stroke(grid, with: .color(Color(ShikakuColors.thin)), lineWidth: 1)

            for region in game.regions {
                let box = frame(region.rect).insetBy(dx: 1.5, dy: 1.5)
                let shape = Path(roundedRect: box, cornerRadius: min(6, cell * 0.18))
                ctx.fill(shape, with: .color(Color(ShikakuColors.regions[region.color % ShikakuColors.regions.count])))
                let isSelected = game.selected?.rect == region.rect
                ctx.stroke(shape, with: .color(Color(Paper.ink)), lineWidth: isSelected ? 3 : 1.5)
            }

            if let rect = preview {
                let box = frame(rect).insetBy(dx: 1.5, dy: 1.5)
                let shape = Path(roundedRect: box, cornerRadius: min(6, cell * 0.18))
                ctx.fill(shape, with: .color(Color(accent).opacity(0.55)))
                ctx.stroke(shape, with: .color(Color(Paper.ink)), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }

            for clue in game.puzzle?.clues ?? [] {
                let center = CGPoint(x: (CGFloat(clue.index % n) + 0.5) * cell, y: (CGFloat(clue.index / n) + 0.5) * cell)
                ctx.draw(Text(verbatim: "\(clue.area)")
                            .font(.system(size: cell * 0.5, weight: .semibold))
                            .foregroundStyle(Color(Paper.ink)),
                         at: center)
            }

            if let rect = preview {
                // 지금 그리는 영역의 크기를 모서리에 작게 보여준다.
                let box = frame(rect)
                let label = Text(verbatim: "\(rect.height)×\(rect.width)=\(rect.area)")
                    .font(.system(size: max(11, cell * 0.28), weight: .bold))
                    .foregroundStyle(Color(Paper.ink))
                ctx.draw(label, at: CGPoint(x: box.maxX - 4, y: box.minY + 3), anchor: .topTrailing)
            }

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
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    guard game.status == .playing else { return }
                    if dragStart == nil { dragStart = index(at: value.startLocation) }
                    if let i = index(at: value.location, clamp: true) { dragEnd = i }
                }
                .onEnded { _ in finish() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("시카쿠 판")
        .accessibilityValue(Text("\(Int((game.progress * 100).rounded()))% 채움"))
    }

    private func finish() {
        defer { dragStart = nil; dragEnd = nil }
        guard game.status == .playing, let a = dragStart, let b = dragEnd else { return }
        if a == b {
            // 탭: 영역이면 고르고, 1칸짜리 숫자면 바로 영역으로 만든다.
            if let region = game.region(at: a) {
                game.selected = game.selected?.rect == region.rect ? nil : region
            } else if game.clue(at: a)?.area == 1 {
                game.add(.spanning(a, a, size: game.size))
            } else {
                game.selected = nil
            }
            return
        }
        if let problem = game.add(.spanning(a, b, size: game.size)) { onProblem(problem) }
    }

    private func index(at point: CGPoint, clamp: Bool = false) -> Int? {
        let n = game.size
        guard boardWidth > 0 else { return nil }
        let cell = boardWidth / CGFloat(n)
        var c = Int(floor(point.x / cell)), r = Int(floor(point.y / cell))
        if clamp {
            c = min(max(c, 0), n - 1)
            r = min(max(r, 0), n - 1)
        }
        guard (0..<n).contains(c), (0..<n).contains(r) else { return nil }
        return r * n + c
    }
}
