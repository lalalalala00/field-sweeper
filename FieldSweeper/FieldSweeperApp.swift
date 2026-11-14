import SwiftUI

@main
struct FieldSweeperApp: App {
    @AppStorage(AppLanguage.storageKey) private var language = "system"

    var body: some Scene {
        WindowGroup {
            // 언어를 바꾸면 SwiftUI 문구는 locale을 따라 바로 바뀐다. 게임 상태는 그대로 둔다.
            ContentView()
                .environment(\.locale, AppLanguage.locale)
        }
    }
}
