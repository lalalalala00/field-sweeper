import SwiftUI
import UIKit

@main
struct FieldSweeperApp: App {
    /// 화면 모드: "system"(기기 설정을 따름), "light", "dark". 설정에서 고른다.
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            HomeView()
                // 시작할 때 저장된 모드를 건다. 바꿀 때는 설정 화면(AppSettingsView)에서 바로 건다.
                .onAppear { Self.apply(appearance) }
        }
    }

    /// 앱의 모든 창에 화면 모드를 건다. 창에 걸어야 떠 있는 설정 시트까지 바로 바뀐다
    /// (SwiftUI의 preferredColorScheme은 iPad 시트에서 바로 바뀌지 않고, 기기 설정으로 되돌리기도 잘 안 된다).
    @MainActor
    static func apply(_ value: String) {
        let style: UIUserInterfaceStyle = value == "light" ? .light : value == "dark" ? .dark : .unspecified
        for scene in UIApplication.shared.connectedScenes {
            for window in (scene as? UIWindowScene)?.windows ?? [] {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
