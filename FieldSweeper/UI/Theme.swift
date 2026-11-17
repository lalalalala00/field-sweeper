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

/// 새로 만들 게임의 카드 색(거울·짝·스위치네모는 시안 '새 게임 카드 색' 조합 B, 셈네모는 돌 회색, 별네모는 남보라).
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
    /// 셈네모: 계산기 같은 돌 회색. 글자는 Deep Green. 웹 paper.css의 --fill-calc와 같다.
    static let calc = UIColor.dynamic(0xcfc9bb, 0x3a3832)
    static let calcText = Paper.ink
    /// 별네모: 밤하늘 같은 남보라. 글자는 흰색. 웹 paper.css의 --fill-star와 같다.
    static let star = UIColor.dynamic(0x9a9fc4, 0x33364d)
    static let starText = UIColor.dynamic(0xffffff, 0xf2f6ee)
}

/// 웹(docs/assets/paper.css)과 같은 게임 그림 색.
enum PuzzleColors {
    static let cell = UIColor.dynamic(0xfbfaf5, 0x1b1f1a)
    static let thin = UIColor.dynamic(0xd9d5c3, 0x343b32)
    static let user = UIColor.dynamic(0x3d67b0, 0x93b2ff)
    static let wrong = UIColor.dynamic(0xc54a38, 0xff8a78)

    /// 짝네모 길 색(별네모 구역 색으로도 쓴다).
    static let paths: [UIColor] = [
        .dynamic(0xc8743d, 0xe6a57a), .dynamic(0xb08a2e, 0xdcc07a), .dynamic(0x8a68bd, 0xb89be0),
        .dynamic(0x3e9a90, 0x7fcfc5), .dynamic(0xc45f78, 0xe094a6), .dynamic(0x5f9a4c, 0x9cc988),
        .dynamic(0x4f7fc0, 0x8fb0e6), .dynamic(0x8f6243, 0xc9a183), .dynamic(0xb04fa8, 0xe08fd8),
        .dynamic(0x66798a, 0xa9b8c6),
    ]

    // 거울네모
    static let beam = UIColor.dynamic(0xe39a2b, 0xffc861)
    static let mirrorTint = UIColor.dynamic(0xe2d5e0, 0x3e3342)
    static let mirrorFixed = UIColor.dynamic(0xe4e0d3, 0x262b24)

    // 스위치네모
    static let lampOff = UIColor.dynamic(0xcdc8b8, 0x232821)
    static let lampRing = UIColor.dynamic(0x8f8a7a, 0x56604f)
    static let lampOn = UIColor.dynamic(0xf6dd88, 0xd2ae52)
    static let lampCore = UIColor.dynamic(0xfffaf0, 0xfff3cf)
    static let lampGlow = UIColor.dynamic(0xffcd50, 0xffcd64)

    // 셈네모
    static let calcRelated = UIColor.dynamic(0xefece3, 0x22261f)
    static let calcSame = UIColor.dynamic(0xddd8c9, 0x363a31)
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
