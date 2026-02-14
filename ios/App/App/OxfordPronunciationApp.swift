import SwiftUI

@main
struct OxfordPronunciationApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ProgressService())
        }
    }
}
