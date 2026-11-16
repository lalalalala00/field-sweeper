import SwiftUI

extension View {
    /// Apple Pencil Pro를 쥐거나 2세대 펜슬을 두 번 탭하면 perform을 부른다.
    /// 그 밖의 펜슬과 iOS 17.5 미만에서는 아무 일도 하지 않는다.
    func onPencilModeSwitch(perform action: @escaping () -> Void) -> some View {
        modifier(PencilModeSwitch(action: action))
    }
}

private struct PencilModeSwitch: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.5, *) {
            content.modifier(PencilGestures(action: action))
        } else {
            content
        }
    }
}

@available(iOS 17.5, *)
private struct PencilGestures: ViewModifier {
    let action: () -> Void
    @Environment(\.preferredPencilSqueezeAction) private var squeezeAction
    @Environment(\.preferredPencilDoubleTapAction) private var doubleTapAction

    // iPad 설정에서 펜슬 동작을 '끔'으로 해둔 사용자는 존중하고, 그 외에는 모드 전환으로 쓴다.
    func body(content: Content) -> some View {
        content
            .onPencilSqueeze { phase in
                guard squeezeAction != .ignore, case .ended = phase else { return }
                action()
            }
            .onPencilDoubleTap { _ in
                guard doubleTapAction != .ignore else { return }
                action()
            }
    }
}
