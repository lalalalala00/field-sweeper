import SwiftUI

struct MirrorView: View {
    @State private var game = MirrorGame()
    @State private var confirmRestart = false
    @State private var notice: String?
    @State private var noticeID = UUID()

    private var subtitle: String { "\(tr(game.level.name)) · \(game.size)×\(game.size)" }

    private static var levels: [PuzzleLevelInfo] {
        MirrorLevel.allCases.map { level in
            PuzzleLevelInfo(id: level.rawValue, name: level.name,
                            detail: trf("\(level.size)×\(level.size) · 거울 \(level.mirrors.lowerBound)~\(level.mirrors.upperBound)개"),
                            menuLabel: "\(tr(level.name)) · \(level.size)×\(level.size)")
        }
    }

    var body: some View {
        PuzzleHost(kind: .mirror, game: game, levels: Self.levels, subtitle: subtitle,
                   makePuzzle: { id in
                       let level = MirrorLevel(rawValue: id) ?? .easy
                       let puzzle = await Task.detached(priority: .userInitiated) {
                           var rng = SystemRandomNumberGenerator()
                           return MirrorEngine.generate(level, using: &rng)
                       }.value
                       game.start(puzzle)
                   },
                   clearSave: MirrorSave.clear,
                   onStartOver: { confirmRestart = true },
                   canStartOver: game.moves > 0,
                   resultNote: {
                       game.moves <= game.minimum
                           ? trf("최소 조작으로 풀었어요") + " · " + trf("조작 \(game.moves)회")
                           : trf("조작 \(game.moves)회 · 최소 \(game.minimum)회")
                   },
                   board: {
                       MirrorBoard(game: game) { show(trf("고정된 거울이에요")) }
                           .overlay(alignment: .top) { PuzzleNotice(text: notice) }
                           .animation(.easeOut(duration: 0.2), value: notice)
                   },
                   status: { statusLine },
                   controls: { controls },
                   extraMenu: { EmptyView() },
                   extraOverlay: { _ in EmptyView() })
            .alert("처음부터 다시 풀까요?", isPresented: $confirmRestart) {
                Button("취소", role: .cancel) {}
                Button("다시 풀기", role: .destructive) {
                    game.restart()
                    game.save()
                }
            } message: {
                Text("같은 문제를 처음 상태로 되돌려요.")
            }
    }

    @ViewBuilder private var statusLine: some View {
        if let p = game.puzzle, let t = game.trace {
            PuzzleStatusLine(parts: [trf("별 \(t.lit)/\(p.stars.count)"), trf("조작 \(game.moves)회"),
                                     trf("최소 \(game.minimum)회"), t.solved ? trf("도착") : trf("도착 전")],
                             bold: t.solved ? [2, 3] : [2],
                             guide: trf("빛이 모든 별을 지나 목적지로 나가게 해 주세요. 거울을 누르면 방향이 바뀌어요."))
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            PuzzleTool(title: "되돌리기", icon: "arrow.uturn.backward") { game.undo() }
                .disabled(game.history.isEmpty)
        }
        .disabled(game.status != .playing)
    }

    private func show(_ text: String) {
        let id = UUID()
        noticeID = id
        notice = text
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if noticeID == id { notice = nil }
        }
    }
}

/// 판 둘레에 시작점(빛이 나오는 등)과 목적지(과녁)를 놓을 여백을 둔다.
private struct MirrorBoard: View {
    let game: MirrorGame
    let onFixed: () -> Void

    @State private var boardWidth: CGFloat = 0

    private struct Geo {
        let n: Int, cell: CGFloat, m: CGFloat
        init(side: CGFloat, n: Int) {
            self.n = n
            cell = side / (CGFloat(n) + 1.2)
            m = cell * 0.6
        }
        func center(_ i: Int) -> CGPoint {
            CGPoint(x: m + (CGFloat(i % n) + 0.5) * cell, y: m + (CGFloat(i / n) + 0.5) * cell)
        }
        func port(_ p: MirrorPort) -> CGPoint {
            let mid = { (v: Int) in m + (CGFloat(v) + 0.5) * cell }, edge = m * 0.5
            switch p.side {
            case 0: return CGPoint(x: mid(p.k), y: edge)
            case 1: return CGPoint(x: m + CGFloat(n) * cell + edge, y: mid(p.k))
            case 2: return CGPoint(x: mid(p.k), y: m + CGFloat(n) * cell + edge)
            default: return CGPoint(x: edge, y: mid(p.k))
            }
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let g = Geo(side: side, n: game.size)
            let gridRect = CGRect(x: g.m, y: g.m, width: CGFloat(g.n) * g.cell, height: CGFloat(g.n) * g.cell)
            let board = Path(roundedRect: gridRect, cornerRadius: 6)
            ctx.fill(board, with: .color(Color(PuzzleColors.cell)))
            var grid = Path()
            for k in 1..<g.n {
                let v = g.m + CGFloat(k) * g.cell
                grid.move(to: CGPoint(x: v, y: g.m)); grid.addLine(to: CGPoint(x: v, y: gridRect.maxY))
                grid.move(to: CGPoint(x: g.m, y: v)); grid.addLine(to: CGPoint(x: gridRect.maxX, y: v))
            }
            ctx.stroke(grid, with: .color(Color(PuzzleColors.thin)), lineWidth: 1)
            guard let p = game.puzzle, let tr = game.trace else {
                ctx.stroke(board, with: .color(Color(Paper.ink)), lineWidth: 2)
                return
            }

            // 칸 바탕: 돌릴 수 있는 거울, 고정 거울, 벽
            for (i, cell) in p.cells.enumerated() {
                let x = g.m + CGFloat(i % g.n) * g.cell, y = g.m + CGFloat(i / g.n) * g.cell
                switch cell {
                case .wall:
                    ctx.fill(Path(roundedRect: CGRect(x: x + 3, y: y + 3, width: g.cell - 6, height: g.cell - 6), cornerRadius: g.cell * 0.14),
                             with: .color(Color(Paper.inkSoft)))
                case .mirror(_, let fixed):
                    ctx.fill(Path(roundedRect: CGRect(x: x + 2, y: y + 2, width: g.cell - 4, height: g.cell - 4), cornerRadius: g.cell * 0.14),
                             with: .color(Color(fixed ? PuzzleColors.mirrorFixed : PuzzleColors.mirrorTint)))
                case .empty:
                    break
                }
            }

            // 빛
            var points = [g.port(p.start)] + tr.path.map(g.center)
            var endMark: CGPoint?
            if let exit = tr.exit {
                let e = g.port(exit)
                points.append(e)
                if !tr.solved && !(exit.side == p.goal.side && exit.k == p.goal.k) { endMark = e }
            } else if let blocked = tr.blocked, let last = points.last {
                let w = g.center(blocked)
                let stop = CGPoint(x: (last.x + w.x) / 2, y: (last.y + w.y) / 2)
                points.append(stop)
                endMark = stop
            }
            var beam = Path()
            beam.addLines(points)
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: Color(PuzzleColors.beam).opacity(0.55), radius: g.cell * 0.18))
                layer.stroke(beam, with: .color(Color(PuzzleColors.beam)),
                             style: StrokeStyle(lineWidth: max(3, g.cell * 0.1), lineCap: .round, lineJoin: .round))
            }

            // 거울
            for (i, cell) in p.cells.enumerated() {
                guard case .mirror(let fixedOrientation, let fixed) = cell else { continue }
                let o = fixed ? fixedOrientation : (game.orient[i] ?? fixedOrientation)
                let c = g.center(i), h = g.cell * 0.32
                let a = o == 0 ? CGPoint(x: c.x - h, y: c.y + h) : CGPoint(x: c.x - h, y: c.y - h)
                let b = o == 0 ? CGPoint(x: c.x + h, y: c.y - h) : CGPoint(x: c.x + h, y: c.y + h)
                var glass = Path(); glass.move(to: a); glass.addLine(to: b)
                ctx.stroke(glass, with: .color(Color(fixed ? Paper.inkSoft : Paper.ink)),
                           style: StrokeStyle(lineWidth: max(3, g.cell * 0.09), lineCap: .round))
                if fixed {
                    // 고정 거울은 양 끝에 못
                    for pt in [a, b] {
                        let r = g.cell * 0.06
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(Color(Paper.inkSoft)))
                    }
                }
            }

            // 별: 빛이 지나가면 채워진다
            let lit = Set(tr.path)
            for s in p.stars {
                let shape = Self.star(at: g.center(s), radius: g.cell * 0.24)
                if lit.contains(s) {
                    ctx.fill(shape, with: .color(Color(PuzzleColors.beam)))
                    ctx.stroke(shape, with: .color(Color(Paper.ink)), lineWidth: 1.2)
                } else {
                    ctx.stroke(shape, with: .color(Color(Paper.inkSoft)), lineWidth: 1.6)
                }
            }
            ctx.stroke(board, with: .color(Color(Paper.ink)), lineWidth: 2)

            // 시작점: 빛이 나오는 작은 등, 목적지: 과녁
            let r = g.m * 0.36
            let s = g.port(p.start)
            let lamp = Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2))
            ctx.fill(lamp, with: .color(Color(PuzzleColors.beam)))
            ctx.stroke(lamp, with: .color(Color(Paper.ink)), lineWidth: 1.5)
            let goal = g.port(p.goal)
            let target = Path(ellipseIn: CGRect(x: goal.x - r, y: goal.y - r, width: r * 2, height: r * 2))
            ctx.fill(target, with: .color(Color(tr.solved ? PuzzleColors.beam : Paper.bg)))
            ctx.stroke(target, with: .color(Color(Paper.ink)), lineWidth: 2)
            let dot = r * 0.38
            ctx.fill(Path(ellipseIn: CGRect(x: goal.x - dot, y: goal.y - dot, width: dot * 2, height: dot * 2)), with: .color(Color(Paper.ink)))

            // 빛이 엉뚱한 곳으로 나가거나 벽에 막히면 그 자리에 ×
            if let e = endMark, game.status == .playing {
                let a = g.m * 0.22
                var x = Path()
                x.move(to: CGPoint(x: e.x - a, y: e.y - a)); x.addLine(to: CGPoint(x: e.x + a, y: e.y + a))
                x.move(to: CGPoint(x: e.x + a, y: e.y - a)); x.addLine(to: CGPoint(x: e.x - a, y: e.y + a))
                ctx.stroke(x, with: .color(Color(PuzzleColors.wrong)), lineWidth: 2.5)
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
        .onTapGesture(coordinateSpace: .local) { point in tap(at: point) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(GameKind.mirror.title) 판")
    }

    private func tap(at point: CGPoint) {
        guard game.status == .playing, boardWidth > 0 else { return }
        let g = Geo(side: boardWidth, n: game.size)
        let c = Int(floor((point.x - g.m) / g.cell)), r = Int(floor((point.y - g.m) / g.cell))
        guard (0..<g.n).contains(c), (0..<g.n).contains(r) else { return }
        let i = r * g.n + c
        if !game.turn(i) && game.isMirror(i) { onFixed() }
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
