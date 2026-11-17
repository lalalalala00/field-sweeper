import SwiftUI

struct SwitchView: View {
    @State private var game = SwitchGame()
    @State private var confirmRestart = false

    private var subtitle: String { "\(tr(game.level.name)) · \(game.size)×\(game.size)" }

    private static var levels: [PuzzleLevelInfo] {
        SwitchLevel.allCases.map { level in
            let base = trf("\(level.size)×\(level.size) · 최소 \(level.moves.lowerBound)~\(level.moves.upperBound)회")
            return PuzzleLevelInfo(id: level.rawValue, name: level.name,
                                   detail: base + (level.limitsMoves ? " · " + trf("횟수 제한") : ""),
                                   menuLabel: "\(tr(level.name)) · \(level.size)×\(level.size)")
        }
    }

    var body: some View {
        PuzzleHost(kind: .switchSquares, game: game, levels: Self.levels, subtitle: subtitle,
                   makePuzzle: { id in
                       let level = SwitchLevel(rawValue: id) ?? .easy
                       let recent = Set(SwitchSave.recent)
                       let puzzle = await Task.detached(priority: .userInitiated) {
                           var rng = SystemRandomNumberGenerator()
                           return SwitchEngine.generate(level, avoiding: recent, using: &rng)
                       }.value
                       SwitchSave.recent.append(SwitchEngine.canonicalKey(puzzle.start, size: puzzle.size))
                       game.start(puzzle)
                   },
                   clearSave: SwitchSave.clear,
                   onStartOver: { confirmRestart = true },
                   canStartOver: game.moves > 0,
                   resultNote: {
                       game.moves <= game.minimum
                           ? trf("최소 조작으로 풀었어요") + " · " + trf("조작 \(game.moves)회")
                           : trf("조작 \(game.moves)회 · 최소 \(game.minimum)회")
                   },
                   board: { SwitchBoard(game: game) },
                   status: { statusLine },
                   controls: { controls },
                   extraMenu: { EmptyView() },
                   extraOverlay: { newPuzzle in
                       if game.failed { failCard(newPuzzle) }
                   })
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
        if game.puzzle != nil {
            let level = game.level
            let parts = [trf("켜진 불 \(game.lit)/\(game.size * game.size)"), trf("조작 \(game.moves)회")]
                + (level.limitsMoves ? [trf("남은 \(max(0, game.minimum - game.moves))회")]
                   : level.showsMinimum ? [trf("최소 \(game.minimum)회")] : [])
            PuzzleStatusLine(parts: parts, bold: parts.count > 2 ? [2] : [],
                             guide: level.limitsMoves ? trf("최소 횟수 안에 풀어야 해요. 되돌리기도 1회로 세요.")
                                                      : trf("누른 칸의 가로줄과 세로줄이 모두 바뀌어요. 불을 모두 켜 주세요."))
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            PuzzleTool(title: "되돌리기", icon: "arrow.uturn.backward") { game.undo() }
                .disabled(game.history.isEmpty || game.failed)
        }
        .disabled(game.status != .playing)
    }

    /// 지옥에서 최소 횟수를 다 쓰고도 못 풀었을 때.
    private func failCard(_ newPuzzle: @escaping (Int) -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(trf("최소 \(game.minimum)회 안에 풀지 못했어요"))
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                Text(trf("지옥에서는 최소 횟수 안에 모든 불을 켜야 해요."))
                    .font(.subheadline)
                    .foregroundStyle(Color(Paper.inkSoft))
                HStack(spacing: 8) {
                    Button { game.restart(); game.save() } label: { Text("처음부터 다시").frame(maxWidth: .infinity) }
                        .buttonStyle(PaperButtonStyle())
                    Button { newPuzzle(game.level.rawValue) } label: { Text("새 퍼즐").frame(maxWidth: .infinity) }
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

/// 불 칸들. 누르면 그 칸의 가로줄과 세로줄이 모두 바뀐다.
private struct SwitchBoard: View {
    let game: SwitchGame

    var body: some View {
        let n = game.size
        VStack(spacing: 6) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<n, id: \.self) { c in
                        let i = r * n + c
                        LampButton(on: game.state.indices.contains(i) && game.state[i],
                                   flashID: game.flashed.contains(i) ? game.flashID : 0,
                                   label: trf("\(r + 1)행 \(c + 1)열")) { game.press(i) }
                            .disabled(game.status != .playing || game.failed)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(Paper.sheet), in: RoundedRectangle(cornerRadius: 14))
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 480)
    }
}

private struct LampButton: View {
    let on: Bool
    /// 바뀔 때마다 달라지는 값. 바뀌면 살짝 눌렸다 돌아온다.
    let flashID: Int
    let label: String
    let action: () -> Void

    @State private var scale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(on ? PuzzleColors.lampOn : PuzzleColors.lampOff))
                    if on {
                        Circle()
                            .fill(Color(PuzzleColors.lampCore))
                            .frame(width: side * 0.34, height: side * 0.34)
                            .shadow(color: Color(PuzzleColors.lampGlow).opacity(0.85), radius: side * 0.12)
                            .overlay(Circle().stroke(Color(PuzzleColors.lampCore).opacity(0.45), lineWidth: 4))
                    } else {
                        Circle()
                            .stroke(Color(PuzzleColors.lampRing), lineWidth: 2)
                            .frame(width: side * 0.34, height: side * 0.34)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: on)
            }
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(scale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: flashID) { _, id in
            guard id != 0 else { return }
            scale = 0.86
            withAnimation(.easeOut(duration: 0.22)) { scale = 1 }
        }
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityValue(on ? Text("켜짐") : Text("꺼짐"))
    }
}
