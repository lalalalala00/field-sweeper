import SwiftUI
import UIKit

/// 칸 배경과 깃발/지뢰 모양 그리기. 보드와 설정 화면 미리보기가 같이 쓴다.
@MainActor
enum SkinRenderer {
    private static var emojiCache: [String: NSAttributedString] = [:]
    private static var digitCache: [String: NSAttributedString] = [:]

    /// 열린 칸 색이 어두우면 밝은 숫자 색을 쓴다 (직접 고른 색에서도 숫자가 보이도록).
    static func drawDigit(_ n: Int, in rect: CGRect) {
        let size = (rect.height * 0.6).rounded()
        let darkGround = Palette.ground.resolvedColor(with: .current).luminance < 0.45
        let key = "\(n)|\(size)|\(darkGround)"
        let str: NSAttributedString
        if let cached = digitCache[key] {
            str = cached
        } else {
            if digitCache.count > 200 { digitCache.removeAll() }
            let base = UIFont.systemFont(ofSize: size, weight: .heavy)
            let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
            let color = Palette.numbers[n - 1].resolvedColor(with: UITraitCollection(userInterfaceStyle: darkGround ? .dark : .light))
            str = NSAttributedString(string: "\(n)", attributes: [.font: font, .foregroundColor: color])
            digitCache[key] = str
        }
        let s = str.size()
        str.draw(at: CGPoint(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2))
    }

    private static var questionCache: (size: CGFloat, string: NSAttributedString)?

    /// 물음표 표시. 모양 바꾸기와 상관없이 늘 같은 "?"를 쓴다.
    static func drawQuestion(in rect: CGRect) {
        let size = (rect.height * 0.62).rounded()
        let str: NSAttributedString
        if let cached = questionCache, cached.size == size {
            str = cached.string
        } else {
            let base = UIFont.systemFont(ofSize: size, weight: .heavy)
            let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
            str = NSAttributedString(string: "?", attributes: [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.95)])
            questionCache = (size, str)
        }
        let s = str.size()
        str.draw(at: CGPoint(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2))
    }

    static func fill(_ rect: CGRect, _ radius: CGFloat, _ color: UIColor) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
    }

    static func drawTurf(_ rect: CGRect, _ radius: CGFloat) {
        let hi = max(1.5, rect.height * 0.06), lo = max(2, rect.height * 0.09)
        fill(rect, radius, Palette.turfLo)
        fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - lo), radius, Palette.turfHi)
        fill(CGRect(x: rect.minX, y: rect.minY + hi, width: rect.width, height: rect.height - lo - hi), radius, Palette.turf)
    }

    static func draw(_ kind: SkinKind, in rect: CGRect, alpha: CGFloat = 1) {
        draw(kind, skin: SkinStore.shared.skin(kind), in: rect, alpha: alpha)
    }

    static func draw(_ kind: SkinKind, skin: Skin, in rect: CGRect, alpha: CGFloat = 1) {
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        ctx?.setAlpha(alpha)
        defer { ctx?.restoreGState() }

        switch skin {
        case .emoji(let emoji):
            let str = emojiString(emoji, size: (rect.height * 0.62).rounded())
            let size = str.size()
            str.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
        case .photo(let name):
            guard let image = SkinStore.shared.image(named: name) else { return drawClassic(kind, in: rect, dimmed: alpha < 1) }
            let r = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
            UIBezierPath(roundedRect: r, cornerRadius: r.width * 0.22).addClip()
            image.draw(in: r)
        case .classic:
            drawClassic(kind, in: rect, dimmed: alpha < 1)
        }
    }

    /// 설정 화면용 미리보기 칸. 깃발은 덮인 칸 위에, 지뢰는 열린 칸 위에 그린다.
    static func tile(_ kind: SkinKind, skin: Skin, side: CGFloat, dark: Bool) -> UIImage {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let format = UIGraphicsImageRendererFormat(for: traits)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            traits.performAsCurrent {
                let rect = CGRect(x: 0, y: 0, width: side, height: side)
                if kind == .flag { drawTurf(rect, side * 0.2) } else { fill(rect, side * 0.2, Palette.ground) }
                draw(kind, skin: skin, in: rect)
            }
        }
    }

    private static func emojiString(_ emoji: String, size: CGFloat) -> NSAttributedString {
        let key = "\(emoji)|\(size)"
        if let cached = emojiCache[key] { return cached }
        if emojiCache.count > 64 { emojiCache.removeAll() }
        let str = NSAttributedString(string: emoji, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: Palette.ink,
        ])
        emojiCache[key] = str
        return str
    }

    private static func drawClassic(_ kind: SkinKind, in rect: CGRect, dimmed: Bool) {
        // 24×24 격자 기준 도형을 칸의 64% 크기로 그린다.
        let s = rect.width * 0.64 / 24
        let o = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        switch kind {
        case .flag:
            (dimmed ? Palette.inkSoft : Palette.flag).setFill()
            UIBezierPath(rect: CGRect(x: o.x + 6 * s, y: o.y + 2.5 * s, width: 2.2 * s, height: 19.5 * s)).fill()
            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: o.x + 8.2 * s, y: o.y + 3.5 * s))
            tri.addLine(to: CGPoint(x: o.x + 20 * s, y: o.y + 8.6 * s))
            tri.addLine(to: CGPoint(x: o.x + 8.2 * s, y: o.y + 13.7 * s))
            tri.close()
            tri.fill()
        case .mine:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            Palette.mine.setFill()
            Palette.mine.setStroke()
            UIBezierPath(arcCenter: center, radius: 6.4 * s, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
            let spikes = UIBezierPath()
            spikes.lineWidth = 2 * s
            spikes.lineCapStyle = .round
            for k in 0..<8 {
                let a = CGFloat(k) * .pi / 4
                spikes.move(to: CGPoint(x: center.x + cos(a) * 4 * s, y: center.y + sin(a) * 4 * s))
                spikes.addLine(to: CGPoint(x: center.x + cos(a) * 10.5 * s, y: center.y + sin(a) * 10.5 * s))
            }
            spikes.stroke()
        }
    }
}

struct SkinTile: View {
    let kind: SkinKind
    let skin: Skin
    var side: CGFloat = 52
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let _ = SkinStore.shared.version
        Image(uiImage: SkinRenderer.tile(kind, skin: skin, side: side, dark: scheme == .dark))
            .frame(width: side, height: side)
    }
}
