import SwiftUI

@main
struct OxfordPronunciationApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var progressService = ProgressService()
    @State private var vocabularyService = VocabularyService.shared
    @State private var themeManager = ThemeManager.shared
    private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isPendingConfirmation && authService.isGracePeriodExpired {
                    GracePeriodExpiredView()
                        .preferredColorScheme(resolvedColorScheme)
                        .id(themeManager.accent)
                } else if vocabularyService.isLoaded {
                    ContentView()
                        .environment(progressService)
                        .environment(themeManager)
                        .preferredColorScheme(resolvedColorScheme)
                        .id(themeManager.accent)
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
            .onOpenURL { url in
                Task {
                    await authService.handleIncomingAuthURL(url)
                }
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
