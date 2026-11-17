import SwiftUI

struct StarView: View {
    @State private var game = StarGame()
    @State private var confirmClear = false
    @AppStorage("star.showMistakes") private var showMistakes = true
    @AppStorage("star.tintRegions") private var tintRegions = true

    private var subtitle: String {
        guard let p = game.puzzle else { return "" }
        let name = tr(p.level.name)
        return p.k == 1 ? trf("\(name) · \(p.size)×\(p.size) · 별 1개") : trf("\(name) · \(p.size)×\(p.size) · 별 2개")
    }

    private static var levels: [PuzzleLevelInfo] {
        StarLevel.allCases.map { level in
            PuzzleLevelInfo(id: level.rawValue, name: level.name,
                            detail: level.stars == 1 ? trf("\(level.size)×\(level.size) · 별 1개씩") : trf("\(level.size)×\(level.size) · 별 2개씩"),
                            menuLabel: "\(tr(level.name)) · \(level.size)×\(level.size)")
        }
    }

    var body: some View {
        PuzzleHost(kind: .star, game: game, levels: Self.levels, subtitle: subtitle,
                   makePuzzle: { id in
                       let level = StarLevel(rawValue: id) ?? .easy
                       let puzzle = await Task.detached(priority: .userInitiated) {
                           var rng = SystemRandomNumberGenerator()
                           return StarEngine.generate(level, using: &rng)
                       }.value
                       game.start(puzzle)
                   },
                   clearSave: StarSave.clear,
                   onStartOver: { confirmClear = true },
                   canStartOver: game.marks.contains { $0 != StarGame.empty },
                   board: { StarBoard(game: game, showMistakes: showMistakes, tintRegions: tintRegions) },
                   status: { statusLine },
                   controls: { controls },
                   extraMenu: {
                       Section("표시") {
                           Toggle("규칙에 어긋난 별 표시", isOn: $showMistakes)
                           Toggle("구역 색 칠하기", isOn: $tintRegions)
                       }
                   },
                   extraOverlay: { _ in EmptyView() })
            .alert("처음부터 다시 풀까요?", isPresented: $confirmClear) {
                Button("취소", role: .cancel) {}
                Button("다시 풀기", role: .destructive) { game.clearAll() }
            } message: {
                Text("되돌리기로 다시 살릴 수 있어요.")
            }
    }

    @ViewBuilder private var statusLine: some View {
        if let p = game.puzzle {
            PuzzleStatusLine(parts: [trf("별 \(game.stars.count)/\(p.size * p.k)")],
                             guide: p.k == 1 ? trf("가로줄·세로줄·구역마다 별 1개씩. 별끼리는 대각선으로도 닿을 수 없어요.")
                                             : trf("가로줄·세로줄·구역마다 별 2개씩. 별끼리는 대각선으로도 닿을 수 없어요."))
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            PuzzleTool(title: PuzzleTool.undoTitle(game.undosLeft), icon: "arrow.uturn.backward") { game.undo() }
                .disabled(!game.canUndo)
        }
        .disabled(game.status != .playing)
    }
}

/// 누르면 빈칸 → 점 → 별 → 빈칸. 빈칸에서 끌면 지나는 빈칸에 점을 찍고, 점에서 끌면 지나는 점을 지운다(별은 그대로).
private struct StarBoard: View {
    let game: StarGame
    let showMistakes: Bool
    let tintRegions: Bool

    @State private var first: Int?
    @State private var paint: (from: UInt8, to: UInt8)?
    @State private var preview: [UInt8]?
    @State private var boardWidth: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let frame = Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: 6)
            ctx.fill(frame, with: .color(Color(PuzzleColors.cell)))
            if let p = game.puzzle {
                let n = p.size, cell = side / CGFloat(n), reg = p.regions
                let marks = preview ?? game.marks
                if tintRegions {
                    for i in 0..<(n * n) {
                        let color = PuzzleColors.paths[(reg[i] * 3) % 10]
                        ctx.fill(Path(CGRect(x: CGFloat(i % n) * cell, y: CGFloat(i / n) * cell, width: cell + 0.5, height: cell + 0.5)),
                                 with: .color(Color(color).opacity(0.16)))
                    }
                }
                var grid = Path()
                for k in 1..<n {
                    let v = CGFloat(k) * cell
                    grid.move(to: CGPoint(x: v, y: 0)); grid.addLine(to: CGPoint(x: v, y: side))
                    grid.move(to: CGPoint(x: 0, y: v)); grid.addLine(to: CGPoint(x: side, y: v))
                }
                ctx.stroke(grid, with: .color(Color(PuzzleColors.thin)), lineWidth: 1)
                var walls = Path()
                for i in 0..<(n * n) {
                    let r = i / n, c = i % n
                    if c < n - 1 && reg[i] != reg[i + 1] {
                        walls.move(to: CGPoint(x: CGFloat(c + 1) * cell, y: CGFloat(r) * cell))
                        walls.addLine(to: CGPoint(x: CGFloat(c + 1) * cell, y: CGFloat(r + 1) * cell))
                    }
                    if r < n - 1 && reg[i] != reg[i + n] {
                        walls.move(to: CGPoint(x: CGFloat(c) * cell, y: CGFloat(r + 1) * cell))
                        walls.addLine(to: CGPoint(x: CGFloat(c + 1) * cell, y: CGFloat(r + 1) * cell))
                    }
                }
                ctx.stroke(walls, with: .color(Color(Paper.ink)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                let bad = showMistakes ? game.bad(for: marks) : []
                for i in 0..<(n * n) {
                    let center = CGPoint(x: (CGFloat(i % n) + 0.5) * cell, y: (CGFloat(i / n) + 0.5) * cell)
                    if marks[i] == StarGame.dot {
                        let r = max(2, cell * 0.07)
                        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Color(Paper.inkSoft)))
                    } else if marks[i] == StarGame.star {
                        ctx.fill(Self.star(at: CGPoint(x: center.x, y: center.y + cell * 0.02), radius: cell * 0.33),
                                 with: .color(Color(bad.contains(i) ? PuzzleColors.wrong : Paper.ink)))
                    }
                }
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
                    if first == nil {
                        first = index(at: value.startLocation)
                        return
                    }
                    guard let start = first, let i = index(at: value.location) else { return }
                    if paint == nil {
                        if i == start || game.marks[start] == StarGame.star { return }
                        let from = game.marks[start]
                        let to = from == StarGame.empty ? StarGame.dot : StarGame.empty
                        paint = (from, to)
                        var next = game.marks
                        next[start] = to
                        preview = next
                    }
                    if let paint, preview?[i] == paint.from { preview?[i] = paint.to }
                }
                .onEnded { _ in
                    defer { first = nil; paint = nil; preview = nil }
                    guard game.status == .playing, let start = first else { return }
                    if let next = preview { game.commit(next) } else { game.cycle(start) }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(GameKind.star.title) 판")
    }

    private func index(at point: CGPoint) -> Int? {
        let n = game.size
        guard boardWidth > 0 else { return nil }
        let cell = boardWidth / CGFloat(n)
        let c = Int(floor(point.x / cell)), r = Int(floor(point.y / cell))
        guard (0..<n).contains(c), (0..<n).contains(r) else { return nil }
        return r * n + c
    }

    static func star(at c: CGPoint, radius r: CGFloat) -> Path {
        var path = Path()
        for k in 0..<10 {
            let a = -Double.pi / 2 + Double(k) * .pi / 5
            let rr = k % 2 == 1 ? r * 0.45 : r
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if k == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
