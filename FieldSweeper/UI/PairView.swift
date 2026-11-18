import SwiftUI

struct PairView: View {
    @State private var game = PairGame()
    @State private var confirmClear = false

    private var subtitle: String { "\(tr(game.level.name)) · \(game.size)×\(game.size)" }

    private static var levels: [PuzzleLevelInfo] {
        PairLevel.allCases.map { level in
            PuzzleLevelInfo(id: level.rawValue, name: level.name,
                            detail: level.fullCover ? trf("\(level.size)×\(level.size) · 모든 칸 채우기")
                                                    : trf("\(level.size)×\(level.size) · 빈칸 허용"),
                            menuLabel: "\(tr(level.name)) · \(level.size)×\(level.size)")
        }
    }

    var body: some View {
        PuzzleHost(kind: .pair, game: game, levels: Self.levels, subtitle: subtitle,
                   makePuzzle: { id in
                       let level = PairLevel(rawValue: id) ?? .easy
                       // 미리 만들어 둔 판이 있으면 기다리지 않고 바로 쓴다(PuzzleStock)
                       let puzzle: PairPuzzle
                       if let ready = PuzzleStock.take(.pair, levelID: id, as: PairPuzzle.self) {
                           puzzle = ready
                       } else {
                           puzzle = await Task.detached(priority: .userInitiated) {
                               var rng = SystemRandomNumberGenerator()
                               return PairEngine.generate(level, using: &rng)
                           }.value
                       }
                       game.start(puzzle)
                       PuzzleStock.refill(.pair, levelID: id) { () -> PairPuzzle? in
                           var rng = SystemRandomNumberGenerator()
                           return PairEngine.generate(level, using: &rng)
                       }
                   },
                   clearSave: PairSave.clear,
                   onStartOver: { confirmClear = true },
                   canStartOver: !game.paths.isEmpty,
                   board: { PairBoard(game: game) },
                   status: { statusLine },
                   controls: { controls },
                   extraMenu: { EmptyView() },
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
            let used = game.paths.reduce(0) { $0 + $1.count }
            let parts = [trf("연결 \(game.completeCount)/\(game.totalPairs)")]
                + (p.fullCover ? [trf("빈칸 \(p.size * p.size - p.walls.count - used)")] : [])
            PuzzleStatusLine(parts: parts,
                             guide: p.fullCover ? trf("같은 숫자끼리 숫자만큼의 칸으로 이어 주세요. 모든 칸을 채워야 해요.")
                                                : trf("같은 숫자끼리 숫자만큼의 칸으로 이어 주세요. 길은 겹칠 수 없어요."))
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

/// 손가락으로 길을 그린다. 숫자에서 시작하면 그 숫자의 길을 새로 그리고, 덜 그린 길의 끝에서 시작하면 이어서 그린다.
/// 길은 빠르게 두 번 눌러야 지워진다(시카쿠와 같다).
private struct PairBoard: View {
    let game: PairGame

    /// 지금 그리는 길. others는 이 길을 뺀 나머지 길들.
    private struct Drawing {
        var cells: [Int]
        var target: Int
        var done = false
        var others: [[Int]]
    }

    @State private var drawing: Drawing?
    @State private var tapPath: Int?
    @State private var moved = false
    @State private var started = false
    /// 첫 번째 탭을 받은 길(양 끝 칸). 곧이어 한 번 더 누르면 지운다.
    @State private var armed: (key: [Int], at: Date)?
    @State private var boardWidth: CGFloat = 0

    private static let doubleTapWindow: TimeInterval = 0.35

    private func color(_ length: Int) -> UIColor {
        PuzzleColors.paths[((length - 3) % 10 + 10) % 10]
    }

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: 6), with: .color(Color(PuzzleColors.cell)))
            let n = game.size, cell = side / CGFloat(n)
            var grid = Path()
            for k in 1..<n {
                let v = CGFloat(k) * cell
                grid.move(to: CGPoint(x: v, y: 0)); grid.addLine(to: CGPoint(x: v, y: side))
                grid.move(to: CGPoint(x: 0, y: v)); grid.addLine(to: CGPoint(x: side, y: v))
            }
            ctx.stroke(grid, with: .color(Color(PuzzleColors.thin)), lineWidth: 1)
            if let p = game.puzzle {
                func center(_ i: Int) -> CGPoint { CGPoint(x: (CGFloat(i % n) + 0.5) * cell, y: (CGFloat(i / n) + 0.5) * cell) }
                for w in p.walls {
                    ctx.fill(Path(roundedRect: CGRect(x: CGFloat(w % n) * cell + 3, y: CGFloat(w / n) * cell + 3, width: cell - 6, height: cell - 6),
                                  cornerRadius: cell * 0.14), with: .color(Color(Paper.inkSoft)))
                }
                let all = drawing.map { $0.others + [$0.cells] } ?? game.paths
                for path in all {
                    guard let first = path.first, let length = p.clues[first] else { continue }
                    let col = Color(color(length))
                    let complete = PairGame.isComplete(path, p)
                    for i in path {
                        ctx.fill(Path(CGRect(x: CGFloat(i % n) * cell + 1, y: CGFloat(i / n) * cell + 1, width: cell - 2, height: cell - 2)),
                                 with: .color(col.opacity(complete ? 0.26 : 0.14)))
                    }
                    if path.count > 1 {
                        var line = Path()
                        line.addLines(path.map(center))
                        let width = max(4, cell * 0.2)
                        if let armed, armed.key == [path[0], path[path.count - 1]] {
                            ctx.stroke(line, with: .color(Color(Paper.ink)), style: StrokeStyle(lineWidth: width + 6, lineCap: .round, lineJoin: .round))
                        }
                        ctx.stroke(line, with: .color(col), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                    }
                }
                // 숫자: 이어지면 길 색으로 채운다
                var done = Set<Int>()
                for path in all where PairGame.isComplete(path, p) { done.insert(path[0]); done.insert(path[path.count - 1]) }
                for (i, length) in p.clues {
                    let c = center(i), r = cell * 0.34
                    let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                    if done.contains(i) {
                        ctx.fill(dot, with: .color(Color(color(length))))
                    } else {
                        ctx.fill(dot, with: .color(Color(PuzzleColors.cell)))
                        ctx.stroke(dot, with: .color(Color(color(length))), lineWidth: 2.5)
                    }
                    ctx.draw(Text(verbatim: "\(length)").font(.system(size: cell * 0.4, weight: .bold))
                                .foregroundStyle(Color(done.contains(i) ? Paper.bg : Paper.ink)),
                             at: CGPoint(x: c.x, y: c.y + cell * 0.02))
                }
                // 그리는 중인 길의 길이 "3/5"
                if let d = drawing, d.cells.count > 1, let last = d.cells.last {
                    let tip = center(last)
                    let label = Text(verbatim: "\(d.cells.count)/\(d.target)")
                        .font(.system(size: max(12, cell * 0.3), weight: .bold)).foregroundStyle(Color(Paper.bg))
                    let resolved = ctx.resolve(label)
                    let textSize = resolved.measure(in: CGSize(width: 200, height: 100))
                    let w = textSize.width + 12, h = max(20, cell * 0.42)
                    let x = min(max(tip.x + cell * 0.35, w / 2 + 2), side - w / 2 - 2)
                    let y = max(tip.y - cell * 0.55, h / 2 + 2)
                    ctx.fill(Path(roundedRect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), cornerRadius: h / 2),
                             with: .color(Color(Paper.ink)))
                    ctx.draw(resolved, at: CGPoint(x: x, y: y + 1))
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
                    if !started {
                        started = true
                        begin(at: value.startLocation)
                    }
                    guard drawing != nil, let goal = index(at: value.location, clamp: true) else { return }
                    follow(to: goal)
                    if value.translation != .zero { moved = true }
                }
                .onEnded { _ in finish() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(GameKind.pair.title) 판")
    }

    private func begin(at point: CGPoint) {
        moved = false
        tapPath = nil
        guard let i = index(at: point), !game.isWall(i) else { return }
        let paths = game.paths
        let owner = paths.firstIndex { $0.contains(i) }
        if let clue = game.clue(at: i) {
            // 숫자에서 시작: 그 숫자에 붙은 길은 지우고 새로 그린다
            drawing = Drawing(cells: [i], target: clue, others: paths.filter { !$0.contains(i) })
        } else if let owner, let p = game.puzzle, !PairGame.isComplete(paths[owner], p), paths[owner].last == i,
                  let first = paths[owner].first, let clue = game.clue(at: first) {
            // 덜 그린 길의 끝에서 시작: 이어서 그린다
            drawing = Drawing(cells: paths[owner], target: clue, others: paths.enumerated().filter { $0.offset != owner }.map(\.element))
        } else if let owner {
            tapPath = owner
        }
    }

    /// 빠르게 그어도 칸을 건너뛰지 않게 한 칸씩 따라간다.
    private func follow(to goal: Int) {
        let n = game.size
        for _ in 0..<(2 * n) {
            guard let cur = drawing?.cells.last, cur != goal else { break }
            let dr = goal / n - cur / n, dc = goal % n - cur % n
            let next = abs(dr) >= abs(dc) ? cur + dr.signum() * n : cur + dc.signum()
            if !step(to: next) { break }
        }
    }

    private func step(to j: Int) -> Bool {
        guard var d = drawing else { return false }
        defer { drawing = d }
        let len = d.cells.count
        if len >= 2 && j == d.cells[len - 2] {          // 한 칸 되돌아가기
            d.cells.removeLast()
            d.done = false
            return true
        }
        if let at = d.cells.firstIndex(of: j) {         // 지나온 칸으로 돌아가기
            d.cells.removeSubrange((at + 1)...)
            d.done = false
            return true
        }
        if d.done || game.isWall(j) || d.others.contains(where: { $0.contains(j) }) { return false }
        if let clue = game.clue(at: j) {
            if clue == d.target && j != d.cells[0] && len + 1 == d.target {
                d.cells.append(j)
                d.done = true
                return true
            }
            return false
        }
        if len + 1 > d.target - 1 { return false }      // 마지막 한 칸은 짝 숫자 자리
        d.cells.append(j)
        return true
    }

    private func finish() {
        defer { drawing = nil; tapPath = nil; started = false }
        guard game.status == .playing else { return }
        if let d = drawing {
            if d.cells.count > 1 {
                game.commit(d.others + [d.cells])
            } else if let own = game.paths.first(where: { $0.contains(d.cells[0]) }) {
                // 숫자를 끌지 않고 누르기만 했다: 그 숫자에 붙은 길을 누른 것과 같다.
                tap(on: own)
            }
        } else if let k = tapPath, !moved, game.paths.indices.contains(k) {
            tap(on: game.paths[k])
        }
    }

    private func tap(on path: [Int]) {
        guard let first = path.first, let last = path.last else { return }
        let key = [first, last]
        if let armed, armed.key == key, Date.now.timeIntervalSince(armed.at) < Self.doubleTapWindow {
            self.armed = nil
            if let k = game.paths.firstIndex(of: path) { game.remove(pathAt: k) }
            return
        }
        let mark = (key: key, at: Date.now)
        armed = mark
        Task {
            try? await Task.sleep(for: .seconds(Self.doubleTapWindow))
            if armed?.key == mark.key && armed?.at == mark.at { armed = nil }
        }
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
