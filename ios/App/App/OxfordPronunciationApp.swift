import SwiftUI

@main
struct OxfordPronunciationApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @StateObject private var progressService = ProgressService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(progressService)
                .preferredColorScheme(resolvedColorScheme)
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
