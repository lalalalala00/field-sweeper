import SwiftUI

@main
struct FieldSweeperApp: App {
    /// 화면 모드: "system"(기기 설정을 따름), "light", "dark". 설정에서 고른다.
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        }
    }
}
