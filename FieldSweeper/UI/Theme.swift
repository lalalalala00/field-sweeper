import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: 1)
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

/// 잔디(덮인 칸)와 흙(열린 칸). 다크 모드는 밤의 들판.
enum Palette {
    static let bg = UIColor.dynamic(0xf6f4ec, 0x151914)
    static let panel = UIColor.dynamic(0xf9fbf6, 0x182016)
    static let ink = UIColor.dynamic(0x1f2a1c, 0xe4ead9)
    static let inkSoft = UIColor.dynamic(0x5b6955, 0x9aa78f)
    static let line = UIColor.dynamic(0xd3dbc9, 0x2b3527)
    /// 상단 패널 바탕과 그 위의 버튼.
    static let well = UIColor.dynamic(0xe2e7d9, 0x182016)
    static let raised = UIColor.dynamic(0xfbfcf9, 0x26301f)

    // 필드 색은 설정에서 바꿀 수 있다.
    @MainActor static var turf: UIColor { SkinStore.shared.fieldPalette.turf }
    @MainActor static var turfHi: UIColor { SkinStore.shared.fieldPalette.turfHi }
    @MainActor static var turfLo: UIColor { SkinStore.shared.fieldPalette.turfLo }
    @MainActor static var ground: UIColor { SkinStore.shared.fieldPalette.ground }
    @MainActor static var board: UIColor { SkinStore.shared.fieldPalette.board }

    static let flag = UIColor.dynamic(0xd4553c, 0xff6b4e)
    static let mine = UIColor.dynamic(0x22291e, 0xe9eee0)
    static let hit = UIColor.dynamic(0xf4a290, 0x7c2b1f)
    static let moss = UIColor.dynamic(0x355f25, 0x9cd17c)
    static let onMoss = UIColor.dynamic(0xf4f8ee, 0x13200e)

    static let numbers: [UIColor] = [
        .dynamic(0x3d67b0, 0x84aaff), .dynamic(0x3b7d47, 0x74d083),
        .dynamic(0xc54a38, 0xff7c68), .dynamic(0x64519a, 0xb8a0ff),
        .dynamic(0x973816, 0xffad73), .dynamic(0x10808a, 0x5fd6d8),
        .dynamic(0x1f2a1c, 0xe4ead9), .dynamic(0x6c7766, 0x9aa78f),
    ]
}

/// 메인 화면, 기록, 공통 설정에 쓰는 메모지 색. Paper Ivory 종이에 Deep Green 잉크.
enum Paper {
    static let bg = UIColor.dynamic(0xf6f4ec, 0x151914)
    static let ink = UIColor.dynamic(0x344a39, 0xdce5d6)
    static let inkSoft = UIColor.dynamic(0x56645a, 0x9aa79a)
    static let rule = UIColor.dynamic(0xb9c0b2, 0x3a4339)
    static let sheet = UIColor.dynamic(0xeeebe0, 0x1d221c)
}

/// 보조 팔레트. 게임 카드 색 후보에서 남은 색들로, 시카쿠 영역 색이나 상태 표시처럼
/// 게임 안에서 색이 더 필요할 때 쓴다. 카드의 대표 색(GameKind.fill)으로는 쓰지 않는다.
/// 단, 민트는 스위치네모 카드 색으로 쓴다(NewGameCards).
enum SubPalette {
    static let rose = UIColor.dynamic(0xd4a99e, 0x4a3330)
    static let apricot = UIColor.dynamic(0xf1dccb, 0x3d3028)
    static let lilac = UIColor.dynamic(0xc4bbd8, 0x37324a)
    static let mint = UIColor.dynamic(0xbfd8cc, 0x2c3d35)

    static let all: [UIColor] = [rose, apricot, lilac, mint]
}

/// 새로 만들 게임 3종의 카드 색(시안 '새 게임 카드 색' 조합 B).
/// 각 게임을 GameKind에 추가할 때 fill과 text로 옮기고, 여기서는 지운다.
enum NewGameCards {
    /// 거울네모: 자두. 글자는 흰색(지뢰찾기·후토시키 카드와 같은 쪽).
    static let mirror = UIColor.dynamic(0xc3a8c6, 0x483c49)
    static let mirrorText = UIColor.dynamic(0xffffff, 0xf2f6ee)
    /// 짝네모: 점토 로즈. 글자는 Deep Green.
    static let pair = UIColor.dynamic(0xdfb3b7, 0x55383a)
    static let pairText = Paper.ink
    /// 스위치네모: 민트(보조 팔레트). 글자는 Deep Green.
    static let switches = SubPalette.mint
    static let switchesText = Paper.ink
}

extension Color {
    init(_ ui: UIColor) { self.init(uiColor: ui) }
}

struct FieldButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(Color(prominent ? Palette.onMoss : Palette.ink))
            .background(Color(prominent ? Palette.moss : Palette.panel), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if !prominent { RoundedRectangle(cornerRadius: 12).strokeBorder(Color(Palette.line)) }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

@MainActor
enum Haptics {
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let notice = UINotificationFeedbackGenerator()

    static func play(_ feedback: Feedback) {
        switch feedback {
        case .flag: medium.impactOccurred()
        case .unflag: light.impactOccurred(intensity: 0.6)
        case .mark: light.impactOccurred(intensity: 0.45)
        case .denied: light.impactOccurred(intensity: 0.4)
        case .boom: notice.notificationOccurred(.error)
        case .win: notice.notificationOccurred(.success)
        case .reveal, .none: break
        }
    }
}
