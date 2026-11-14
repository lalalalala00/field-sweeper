import SwiftUI
import UIKit

/// 칸이 2,500개까지 늘어날 수 있어서 SwiftUI 뷰 대신 UIKit 스크롤 뷰에 화면에 보이는 칸만 직접 그린다.
struct BoardView: UIViewRepresentable {
    let game: Game
    let version: Int
    let skinVersion: Int
    let fitPitch: ClosedRange<CGFloat>
    let onAction: (Int, Bool) -> Void

    func makeUIView(context: Context) -> BoardScrollView {
        let view = BoardScrollView()
        view.fitPitch = fitPitch
        return view
    }

    func updateUIView(_ view: BoardScrollView, context: Context) {
        view.game = game
        view.onAction = onAction
        view.render()
    }
}

final class BoardScrollView: UIScrollView {
    var game: Game?
    var onAction: ((Int, Bool) -> Void)?
    var fitPitch: ClosedRange<CGFloat> = 28...46

    private let canvas = BoardCanvas()
    private let zoomPitch: ClosedRange<CGFloat> = 14...88
    private(set) var pitch: CGFloat = 36
    private var generation = -1
    private var fittedSize: CGSize = .zero
    private var pinchStart = (pitch: CGFloat(0), fx: CGFloat(0), fy: CGFloat(0))
    private let pinchDelegate = SimultaneousDelegate()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        delaysContentTouches = false
        contentInsetAdjustmentBehavior = .never
        canvas.board = self
        canvas.isUserInteractionEnabled = false
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        addSubview(canvas)

        let long = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        long.minimumPressDuration = 0.35
        long.allowableMovement = 10
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        tap.require(toFail: long)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = pinchDelegate
        [tap, long, pinch].forEach(addGestureRecognizer)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: BoardScrollView, _) in
            view.canvas.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func render() {
        guard let game else { return }
        if game.generation != generation {
            generation = game.generation
            fittedSize = .zero
            setNeedsLayout()
        }
        canvas.setNeedsDisplay()
    }

    // MARK: Geometry

    private var gap: CGFloat { max(1.5, (pitch * 0.07).rounded()) }

    private var boardSize: CGSize {
        guard let game else { return .zero }
        return CGSize(width: CGFloat(game.cols) * pitch + gap, height: CGFloat(game.rows) * pitch + gap)
    }

    /// 보드가 화면보다 작으면 가운데에 둔다.
    private var boardOrigin: CGPoint {
        let size = boardSize
        return CGPoint(x: max(0, (bounds.width - size.width) / 2), y: max(0, (bounds.height - size.height) / 2))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedSize, bounds.width > 0, bounds.height > 0 {
            fittedSize = bounds.size
            fit()
        }
        let visible = CGRect(origin: contentOffset, size: bounds.size)
        if canvas.frame != visible {
            canvas.frame = visible
            canvas.setNeedsDisplay()
        }
    }

    private func fit() {
        guard let game, game.cols > 0 else { return }
        let p = floor(min((bounds.width - 4) / CGFloat(game.cols), (bounds.height - 4) / CGFloat(game.rows)))
        setPitch(min(max(p, fitPitch.lowerBound), fitPitch.upperBound))
        contentOffset = clamped(CGPoint(x: (contentSize.width - bounds.width) / 2, y: (contentSize.height - bounds.height) / 2))
    }

    private func setPitch(_ value: CGFloat) {
        pitch = min(max(value, zoomPitch.lowerBound), zoomPitch.upperBound)
        contentSize = boardSize
        canvas.setNeedsDisplay()
    }

    private func clamped(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(0, p.x), max(0, contentSize.width - bounds.width)),
                y: min(max(0, p.y), max(0, contentSize.height - bounds.height)))
    }

    private func index(at point: CGPoint) -> Int? {
        guard let game else { return nil }
        let o = boardOrigin
        let x = point.x - o.x - gap, y = point.y - o.y - gap
        guard x >= 0, y >= 0 else { return nil }
        let c = Int(x / pitch), r = Int(y / pitch)
        guard c < game.cols, r < game.rows else { return nil }
        return r * game.cols + c
    }

    // MARK: Gestures

    @objc private func onTap(_ g: UITapGestureRecognizer) {
        if let i = index(at: g.location(in: self)) { onAction?(i, false) }
    }

    @objc private func onLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let i = index(at: g.location(in: self)) else { return }
        onAction?(i, true)
    }

    /// 손가락 사이의 지점이 같은 칸 위에 머물도록 확대/축소한다.
    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        let loc = g.location(in: self)
        switch g.state {
        case .began:
            panGestureRecognizer.isEnabled = false
            let o = boardOrigin, s = boardSize
            pinchStart = (pitch, (loc.x - o.x) / s.width, (loc.y - o.y) / s.height)
        case .changed:
            let screen = CGPoint(x: loc.x - contentOffset.x, y: loc.y - contentOffset.y)
            setPitch(pinchStart.pitch * g.scale)
            let o = boardOrigin, s = boardSize
            contentOffset = clamped(CGPoint(x: o.x + pinchStart.fx * s.width - screen.x,
                                            y: o.y + pinchStart.fy * s.height - screen.y))
            setNeedsLayout()
        default:
            panGestureRecognizer.isEnabled = true
        }
    }

    // MARK: Drawing

    fileprivate func drawBoard(visible: CGRect) {
        guard let game, game.cols > 0 else { return }
        let gap = gap, cell = pitch - gap
        let o = boardOrigin
        let boardRect = CGRect(origin: o, size: boardSize).offsetBy(dx: -visible.minX, dy: -visible.minY)
        Palette.board.setFill()
        UIBezierPath(roundedRect: boardRect, cornerRadius: cell * 0.32).fill()

        let c0 = max(0, Int(floor((visible.minX - o.x - gap) / pitch)))
        let c1 = min(game.cols - 1, Int(floor((visible.maxX - o.x - gap) / pitch)))
        let r0 = max(0, Int(floor((visible.minY - o.y - gap) / pitch)))
        let r1 = min(game.rows - 1, Int(floor((visible.maxY - o.y - gap) / pitch)))
        guard c0 <= c1, r0 <= r1 else { return }

        let radius = cell * 0.2
        let lost = game.status == .lost

        for r in r0...r1 {
            for c in c0...c1 {
                let i = r * game.cols + c
                let rect = CGRect(x: boardRect.minX + gap + CGFloat(c) * pitch,
                                  y: boardRect.minY + gap + CGFloat(r) * pitch,
                                  width: cell, height: cell)
                let s = game.state[i]
                if lost && game.isMine[i] && s != .flagged {
                    SkinRenderer.fill(rect, radius, i == game.hitIndex ? Palette.hit : Palette.ground)
                    SkinRenderer.draw(.mine, in: rect)
                } else if lost && !game.isMine[i] && s == .flagged {
                    SkinRenderer.fill(rect, radius, Palette.ground)
                    SkinRenderer.draw(.flag, in: rect, alpha: 0.45)
                    drawCross(in: rect)
                } else {
                    switch s {
                    case .open:
                        SkinRenderer.fill(rect, radius, Palette.ground)
                        let n = Int(game.adjacent[i])
                        if n > 0 { SkinRenderer.drawDigit(n, in: rect) }
                    case .hidden:
                        SkinRenderer.drawTurf(rect, radius)
                    case .flagged:
                        SkinRenderer.drawTurf(rect, radius)
                        SkinRenderer.draw(.flag, in: rect)
                    }
                }
            }
        }
    }

    private func drawCross(in rect: CGRect) {
        let line = UIBezierPath()
        line.lineWidth = max(1.5, rect.width * 0.07)
        line.lineCapStyle = .round
        line.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.18))
        line.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.18))
        Palette.flag.setStroke()
        line.stroke()
    }
}

private final class BoardCanvas: UIView {
    weak var board: BoardScrollView?

    override func draw(_ rect: CGRect) {
        board?.drawBoard(visible: frame)
    }
}

/// 핀치가 스크롤과 동시에 시작될 수 있게 한다. 핀치가 시작되면 스크롤은 잠시 끈다.
private final class SimultaneousDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other is UIPanGestureRecognizer
    }
}
