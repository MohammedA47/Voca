import SwiftUI

@main
struct OxfordPronunciationApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var progressService = ProgressService()
    @State private var vocabularyService = VocabularyService.shared

    var body: some Scene {
        WindowGroup {
            if vocabularyService.isLoaded {
                ContentView()
                    .environment(progressService)
                    .preferredColorScheme(resolvedColorScheme)
                    .task {
                        // Index vocabulary words in Spotlight
                        SpotlightIndexer.indexAllWords()
                    }
            } else {
                // Show loading state while vocabulary loads
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading vocabulary...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .preferredColorScheme(resolvedColorScheme)
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
