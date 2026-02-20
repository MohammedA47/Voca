import SwiftUI

@main
struct OxfordPronunciationApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ProgressService())
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
