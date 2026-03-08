import SwiftUI

@main
struct OxfordPronunciationApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var progressService = ProgressService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progressService)
                .preferredColorScheme(resolvedColorScheme)
                .task {
                    // Index vocabulary words in Spotlight once loaded
                    while !VocabularyService.shared.isLoaded {
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                    SpotlightIndexer.indexAllWords()
                }
        }
    }
    
    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
