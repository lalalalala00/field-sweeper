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
            case .mirror:
                // 거울 한 장과 꺾이는 빛
                let u = s / 24
                var glass = Path()
                glass.move(to: CGPoint(x: 7 * u, y: 17 * u)); glass.addLine(to: CGPoint(x: 17 * u, y: 7 * u))
                ctx.stroke(glass, with: .color(color), style: style)
                var light = Path()
                light.move(to: CGPoint(x: 4.5 * u, y: 12 * u)); light.addLine(to: CGPoint(x: 11 * u, y: 12 * u))
                light.addLine(to: CGPoint(x: 11 * u, y: 5.5 * u))
                ctx.stroke(light, with: .color(color), style: StrokeStyle(lineWidth: line * 0.6, lineCap: .round, dash: [1.6 * u, 1.8 * u]))
            case .pair:
                // 두 점을 잇는 길
                let u = s / 24
                var road = Path()
                road.move(to: CGPoint(x: 7 * u, y: 7 * u)); road.addLine(to: CGPoint(x: 7 * u, y: 17 * u))
                road.addLine(to: CGPoint(x: 17 * u, y: 17 * u))
                ctx.stroke(road, with: .color(color), style: StrokeStyle(lineWidth: line * 0.69, lineJoin: .round))
                for (x, y) in [(7.0, 7.0), (17.0, 17.0)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: (x - 2.1) * u, y: (y - 2.1) * u, width: 4.2 * u, height: 4.2 * u)), with: .color(color))
                }
            case .star:
                // 네모 안의 별 하나
                let u = s / 24
                var star = Path()
                for k in 0..<10 {
                    let a = -Double.pi / 2 + Double(k) * .pi / 5, r = k % 2 == 1 ? 2.6 : 6.0
                    let pt = CGPoint(x: (12 + cos(a) * r) * u, y: (12.6 + sin(a) * r) * u)
                    if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                ctx.fill(star, with: .color(color))
            case .calc:
                // 칸 묶음의 덧셈·곱셈
                let u = s / 24
                var marks = Path()
                marks.move(to: CGPoint(x: 8.5 * u, y: 5.5 * u)); marks.addLine(to: CGPoint(x: 8.5 * u, y: 11.5 * u))
                marks.move(to: CGPoint(x: 5.5 * u, y: 8.5 * u)); marks.addLine(to: CGPoint(x: 11.5 * u, y: 8.5 * u))
                marks.move(to: CGPoint(x: 13.4 * u, y: 13.4 * u)); marks.addLine(to: CGPoint(x: 18.6 * u, y: 18.6 * u))
                marks.move(to: CGPoint(x: 18.6 * u, y: 13.4 * u)); marks.addLine(to: CGPoint(x: 13.4 * u, y: 18.6 * u))
                ctx.stroke(marks, with: .color(color), style: StrokeStyle(lineWidth: line * 0.66, lineCap: .round))
            case .switchSquares:
                // 누른 칸과 함께 바뀌는 가로줄·세로줄
                var cross = Path()
                cross.move(to: p(0.5, line / s)); cross.addLine(to: p(0.5, 1 - line / s))
                cross.move(to: p(line / s, 0.5)); cross.addLine(to: p(1 - line / s, 0.5))
                ctx.stroke(cross, with: .color(color), style: StrokeStyle(lineWidth: line * 0.6))
                let r = s * 3.2 / 24
                ctx.fill(Path(ellipseIn: CGRect(x: s / 2 - r, y: s / 2 - r, width: r * 2, height: r * 2)), with: .color(color))
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

/// 메인 카드와 기록 창의 게임 이름. 한국어 화면이면 한국어 이름 옆에 영어 이름을 작게, 다른 언어는 영어 이름만.
struct GameName: View {
    let kind: GameKind
    let color: Color

    /// 앱 안에서 고른 언어, 없으면 기기 설정으로 앱이 실제로 쓰는 언어.
    static var isKorean: Bool {
        (AppLanguage.code ?? Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("ko")
    }

    var body: some View {
        if Self.isKorean {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: kind.koreanTitle)
                    .font(.system(size: 17, weight: .medium))
                Text(verbatim: kind.title)
                    .font(.system(size: 11))
                    .opacity(0.7)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(color)
        } else {
            Text(verbatim: kind.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(color)
        }
    }
}
