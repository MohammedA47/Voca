import SwiftUI

@main
struct OxfordPronunciationApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @Environment(\.scenePhase) private var scenePhase
    @State private var progressService = ProgressService()
    @State private var vocabularyService = VocabularyService.shared
    @State private var themeManager = ThemeManager.shared
    @State private var showPendingPrompt = false
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
                            await SpotlightIndexer.indexAllWordsIfNeeded()
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await evaluatePendingPrompt() }
                }
            }
            .task {
                // Runs once on cold launch, after AuthService.init has loaded state.
                await evaluatePendingPrompt()
            }
            .sheet(isPresented: $showPendingPrompt) {
                NavigationStack {
                    LoginSheetView(startInPendingConfirmation: true)
                }
                .preferredColorScheme(resolvedColorScheme)
                .id(themeManager.accent)
            }
            .fullScreenCover(isPresented: Binding(
                get: { authService.isPasswordRecovery },
                set: { newValue in if !newValue { authService.finishPasswordRecovery() } }
            )) {
                SetNewPasswordView()
                    .preferredColorScheme(resolvedColorScheme)
                    .id(themeManager.accent)
            }
        }
    }
    
    /// Attempts a silent confirmation check, then prompts the user if we're
    /// still pending and inside the 48-hour grace period. The prompt lets them
    /// tap "I've Confirmed My Email" to finish sign-in without retyping the
    /// password (the silent probe uses Keychain-cached credentials).
    @MainActor
    private func evaluatePendingPrompt() async {
        let confirmed = await authService.checkConfirmationStatus()
        if confirmed {
            showPendingPrompt = false
            return
        }
        if authService.isPendingConfirmation && !authService.isGracePeriodExpired {
            showPendingPrompt = true
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
