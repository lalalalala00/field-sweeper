import SwiftUI

struct CalcView: View {
    @State private var game = CalcGame()
    @State private var confirmClearAll = false
    @AppStorage("calc.showConflicts") private var showConflicts = true
    @AppStorage("calc.showWrongCages") private var showWrongCages = true
    @AppStorage("calc.handwriting") private var handwriting = true

    private var subtitle: String { "\(tr(game.level.name)) · \(game.size)×\(game.size)" }

    private static let levels: [PuzzleLevelInfo] = CalcLevel.allCases.map { level in
        PuzzleLevelInfo(id: level.rawValue, name: level.name,
                        detail: "\(level.size)×\(level.size) · " + level.ops.map(\.symbol).filter { !$0.isEmpty }.joined(separator: " "),
                        menuLabel: "\(tr(level.name)) · \(level.size)×\(level.size)")
    }

    var body: some View {
        PuzzleHost(kind: .calc, game: game, levels: Self.levels, subtitle: subtitle,
                   makePuzzle: { id in
                       let level = CalcLevel(rawValue: id) ?? .easy
                       let puzzle = await Task.detached(priority: .userInitiated) {
                           var rng = SystemRandomNumberGenerator()
                           return CalcEngine.generate(level, using: &rng)
                       }.value
                       game.start(puzzle)
                   },
                   clearSave: CalcSave.clear,
                   onStartOver: { confirmClearAll = true },
                   canStartOver: game.hasEntries,
                   board: {
                       CalcBoard(game: game, showConflicts: showConflicts, showWrongCages: showWrongCages, handwriting: handwriting)
                   },
                   status: { EmptyView() },
                   controls: { controls },
                   extraMenu: {
                       Section("표시") {
                           Toggle("중복 숫자 표시", isOn: $showConflicts)
                           Toggle("계산이 틀린 묶음 표시", isOn: $showWrongCages)
                       }
                       if UIDevice.current.userInterfaceIdiom == .pad {
                           Section("입력") { Toggle("펜슬로 숫자 쓰기", isOn: $handwriting) }
                       }
                   },
                   extraOverlay: { _ in EmptyView() })
            .onPencilModeSwitch { game.noteMode.toggle() }
            .alert("처음부터 다시 풀까요?", isPresented: $confirmClearAll) {
                Button("취소", role: .cancel) {}
                Button("다시 풀기", role: .destructive) { game.clearAll() }
            } message: {
                Text("되돌리기로 다시 살릴 수 있어요.")
            }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                PuzzleTool(title: PuzzleTool.undoTitle(game.undosLeft), icon: "arrow.uturn.backward") { game.undo() }
                    .disabled(!game.canUndo)
                PuzzleTool(title: "지우기", icon: "eraser") { game.erase() }
                PuzzleTool(title: game.noteMode ? "메모 켜짐" : "메모", icon: "pencil",
                           active: game.noteMode, accent: GameKind.calc.fill) { game.noteMode.toggle() }
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
                    .foregroundStyle(Color(game.noteMode ? Paper.inkSoft : PuzzleColors.user))
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
}

/// 묶음 경계는 굵은 선, 묶음 안은 가는 선. 묶음 왼쪽 위 칸에 "12×" 이름표.
private struct CalcBoard: View {
    let game: CalcGame
    let showConflicts: Bool
    let showWrongCages: Bool
    let handwriting: Bool

    var body: some View {
        Canvas { ctx, size in
            guard let p = game.puzzle else {
                ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6), with: .color(Color(PuzzleColors.cell)))
                return
            }
            let n = p.size
            let side = min(size.width, size.height)
            let cell = side / CGFloat(n)
            var owner = Array(repeating: -1, count: n * n)
            for (k, cage) in p.cages.enumerated() { for i in cage.cells { owner[i] = k } }
            let conflicts = showConflicts ? game.conflicts : []
            let wrongCages = showWrongCages ? game.wrongCages : []
            let sel = game.selected
            let selValue = sel.map { game.values[$0] } ?? 0

            for i in 0..<(n * n) {
                let rect = CGRect(x: CGFloat(i % n) * cell, y: CGFloat(i / n) * cell, width: cell + 0.5, height: cell + 0.5)
                var fill = PuzzleColors.cell
                if let sel {
                    if i == sel { fill = GameKind.calc.fill }
                    else if selValue != 0 && game.values[i] == selValue { fill = PuzzleColors.calcSame }
                    else if i / n == sel / n || i % n == sel % n { fill = PuzzleColors.calcRelated }
                }
                ctx.fill(Path(rect), with: .color(Color(fill)))
                let v = game.values[i]
                if v != 0 {
                    let given = game.isGiven(i)
                    let color = conflicts.contains(i) && !given ? PuzzleColors.wrong : (given ? Paper.ink : PuzzleColors.user)
                    ctx.draw(Text(verbatim: "\(v)").font(.system(size: cell * 0.46, weight: given ? .semibold : .regular))
                                .foregroundStyle(Color(color)),
                             at: CGPoint(x: rect.minX + cell / 2, y: rect.minY + cell * 0.58))
                } else if game.notes[i] != 0 {
                    // 메모는 이름표 아래 공간에 작게
                    let cols = n <= 4 ? 2 : 3, rows = (n + cols - 1) / cols
                    let top = cell * 0.3, h = cell - top - cell * 0.06
                    for d in 1...n where game.notes[i] & (1 << UInt16(d)) != 0 {
                        let x = rect.minX + cell * (CGFloat((d - 1) % cols) + 0.5) / CGFloat(cols)
                        let y = rect.minY + top + h * (CGFloat((d - 1) / cols) + 0.5) / CGFloat(rows)
                        ctx.draw(Text(verbatim: "\(d)").font(.system(size: cell * (n <= 4 ? 0.2 : 0.17), weight: .medium))
                                    .foregroundStyle(Color(selValue == d ? Paper.ink : Paper.inkSoft)),
                                 at: CGPoint(x: x, y: y))
                    }
                }
            }

            var thin = Path(), thick = Path()
            for i in 0..<(n * n) {
                let r = i / n, c = i % n
                if c < n - 1 {
                    let x = CGFloat(c + 1) * cell
                    var seg = Path(); seg.move(to: CGPoint(x: x, y: CGFloat(r) * cell)); seg.addLine(to: CGPoint(x: x, y: CGFloat(r + 1) * cell))
                    if owner[i] == owner[i + 1] { thin.addPath(seg) } else { thick.addPath(seg) }
                }
                if r < n - 1 {
                    let y = CGFloat(r + 1) * cell
                    var seg = Path(); seg.move(to: CGPoint(x: CGFloat(c) * cell, y: y)); seg.addLine(to: CGPoint(x: CGFloat(c + 1) * cell, y: y))
                    if owner[i] == owner[i + n] { thin.addPath(seg) } else { thick.addPath(seg) }
                }
            }
            ctx.stroke(thin, with: .color(Color(PuzzleColors.thin)), lineWidth: 1)
            ctx.stroke(thick, with: .color(Color(Paper.ink)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            // 묶음 이름표. 1칸 묶음은 숫자가 이미 주어져 있어 쓰지 않는다.
            for (k, cage) in p.cages.enumerated() where cage.op != .equal {
                let i = cage.cells[0]
                let origin = CGPoint(x: CGFloat(i % n) * cell + cell * 0.08, y: CGFloat(i / n) * cell + cell * 0.07)
                ctx.draw(Text(verbatim: cage.label).font(.system(size: max(10, cell * 0.21), weight: .bold))
                            .foregroundStyle(Color(wrongCages.contains(k) ? PuzzleColors.wrong : Paper.ink)),
                         at: origin, anchor: .topLeading)
            }
            ctx.stroke(Path(roundedRect: CGRect(x: 1, y: 1, width: side - 2, height: side - 2), cornerRadius: 6),
                       with: .color(Color(Paper.ink)), lineWidth: 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            ScribbleGridInput(size: game.size, isEnabled: game.status == .playing, handwriting: handwriting,
                              onTap: { i in game.selected = game.selected == i ? nil : i },
                              onFocus: { i in game.selected = i },
                              onWrite: { i, d in
                                  game.selected = i
                                  game.enter(d)
                              })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(GameKind.calc.title) 판")
    }
}
