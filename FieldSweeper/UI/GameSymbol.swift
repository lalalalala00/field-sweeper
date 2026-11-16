import SwiftUI

/// 게임 이름 앞에 붙는 작은 상징. 모두 네모 안에 그 게임을 담은 모양이다.
struct GameSymbol: View {
    let kind: GameKind
    var size: CGFloat = 18
    var color: Color = .primary

    var body: some View {
        Canvas { ctx, canvas in
            let s = min(canvas.width, canvas.height)
            let line = max(1.3, s * 0.085)
            let inset = line / 2
            let frame = CGRect(x: inset, y: inset, width: s - line, height: s - line)
            let style = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            let thin = StrokeStyle(lineWidth: line * 0.6, lineCap: .round)
            ctx.stroke(Path(roundedRect: frame, cornerRadius: s * 0.16), with: .color(color), style: style)

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            switch kind {
            case .minesweeper:
                // 지뢰: 둥근 몸통, 짧은 가시, 반짝이는 점.
                let center = p(0.5, 0.52)
                let r = s * 0.19
                var spikes = Path()
                for k in 0..<8 {
                    let a = Double(k) * .pi / 4
                    let len = k % 2 == 0 ? s * 0.29 : s * 0.25
                    spikes.move(to: center)
                    spikes.addLine(to: CGPoint(x: center.x + cos(a) * len, y: center.y + sin(a) * len))
                }
                ctx.stroke(spikes, with: .color(color), style: thin)
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(color))
                let shine = s * 0.055
                ctx.blendMode = .clear
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.45 - shine, y: center.y - r * 0.45 - shine,
                                                width: shine * 2, height: shine * 2)), with: .color(.black))
                ctx.blendMode = .normal
            case .sudoku:
                // 3×3 칸. 선은 테두리 안쪽 면에 맞닿는다.
                var grid = Path()
                let edge = line / s
                for t in [1.0 / 3 + edge / 3, 2.0 / 3 - edge / 3] {
                    grid.move(to: p(t, edge)); grid.addLine(to: p(t, 1 - edge))
                    grid.move(to: p(edge, t)); grid.addLine(to: p(1 - edge, t))
                }
                ctx.stroke(grid, with: .color(color), style: StrokeStyle(lineWidth: line * 0.6, lineCap: .butt))
            case .shikaku:
                // 크기가 다른 직사각형으로 나눈 판.
                var cuts = Path()
                cuts.move(to: p(0.56, 0.12)); cuts.addLine(to: p(0.56, 0.88))
                cuts.move(to: p(0.12, 0.42)); cuts.addLine(to: p(0.56, 0.42))
                cuts.move(to: p(0.56, 0.66)); cuts.addLine(to: p(0.88, 0.66))
                ctx.stroke(cuts, with: .color(color), style: thin)
            case .futoshiki:
                // 부등호와 밑줄(≤). 뒤로가기 화살표와 헷갈리지 않게 한다.
                var sign = Path()
                sign.move(to: p(0.64, 0.25))
                sign.addLine(to: p(0.36, 0.43))
                sign.addLine(to: p(0.64, 0.61))
                sign.move(to: p(0.36, 0.74))
                sign.addLine(to: p(0.64, 0.74))
                ctx.stroke(sign, with: .color(color), style: style)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
