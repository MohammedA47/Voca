import SwiftUI
import UIKit

// MARK: - Feature Model

struct WelcomeFeature: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    /// Optional per-feature override. Defaults to `Color.accentPrimary` so the
    /// whole screen tracks the user's accent theme.
    var iconColor: Color? = nil
}

/// Hero element shown above the title.
enum WelcomeHero {
    /// The app's icon (loaded from the bundle). Falls back to a symbol tile if
    /// the icon can't be resolved at runtime.
    case appIcon
    /// A custom SF Symbol rendered in a tinted rounded-square tile.
    case symbol(String)
    case none
}

/// Optional footer shown above the continue button — matches the "data
/// management" disclaimer Apple uses on Apple Games / Game Center welcome
/// sheets. The `linkText` is rendered inline in the accent color.
struct WelcomeFooterNote {
    let icon: String
    let text: String
    let linkText: String?
    let linkURL: URL?

    init(icon: String, text: String, linkText: String? = nil, linkURL: URL? = nil) {
        self.icon = icon
        self.text = text
        self.linkText = linkText
        self.linkURL = linkURL
    }
}

// MARK: - Release Manifest

struct WelcomeRelease {
    /// Stable key. Use the marketing version ("1.2.0") or any monotonically
    /// increasing string. Changing this string shows the sheet again.
    let version: String
    let hero: WelcomeHero
    let title: String
    let features: [WelcomeFeature]
    let footerNote: WelcomeFooterNote?
    /// Primary button label on the features page. Apple uses "Continue".
    let buttonTitle: String
    /// Optional follow-up page that lets the user sign in or skip.
    let signInStep: WelcomeSignInStep?

    init(
        version: String,
        hero: WelcomeHero = .appIcon,
        title: String,
        features: [WelcomeFeature],
        footerNote: WelcomeFooterNote? = nil,
        buttonTitle: String = "Continue",
        signInStep: WelcomeSignInStep? = nil
    ) {
        self.version = version
        self.hero = hero
        self.title = title
        self.features = features
        self.footerNote = footerNote
        self.buttonTitle = buttonTitle
        self.signInStep = signInStep
    }
}

/// Second-page configuration — benefits of signing in, plus which auth
/// methods to offer. Reused across releases by pointing to a single manifest.
struct WelcomeSignInStep {
    let hero: WelcomeHero
    let title: String
    let features: [WelcomeFeature]
    let appleButtonTitle: String
    let emailButtonTitle: String
    let skipButtonTitle: String
    let showApple: Bool
    let showEmail: Bool
    let allowSkip: Bool

    init(
        hero: WelcomeHero = .symbol("icloud.fill"),
        title: String = "Sync across your devices",
        features: [WelcomeFeature],
        appleButtonTitle: String = "Continue with Apple",
        emailButtonTitle: String = "Continue with Email",
        skipButtonTitle: String = "Not Now",
        showApple: Bool = true,
        showEmail: Bool = true,
        allowSkip: Bool = true
    ) {
        self.hero = hero
        self.title = title
        self.features = features
        self.appleButtonTitle = appleButtonTitle
        self.emailButtonTitle = emailButtonTitle
        self.skipButtonTitle = skipButtonTitle
        self.showApple = showApple
        self.showEmail = showEmail
        self.allowSkip = allowSkip
    }
}

/// Sign-in method the user picked on the sign-in benefits page.
enum WelcomeSignInMethod: Identifiable {
    case apple
    case email

    var id: String {
        switch self {
        case .apple: return "apple"
        case .email: return "email"
        }
    }
}

enum WhatsNewManifest {
    /// The latest release to showcase. Bump `version` to re-trigger the sheet.
    static let current = WelcomeRelease(
        version: "1.0.0",
        hero: .appIcon,
        title: "Welcome to Voca",
        features: [
            WelcomeFeature(
                icon: "rectangle.stack.fill",
                title: "Beautiful Word Cards",
                description: "Flip through a curated deck with definitions, examples, and pronunciation."
            ),
            WelcomeFeature(
                icon: "sparkles",
                title: "Smart Daily Picks",
                description: "A fresh set of words each day, tuned to what you're ready to learn next."
            ),
            WelcomeFeature(
                icon: "magnifyingglass",
                title: "Search Anywhere",
                description: "Find any word in seconds — even from Spotlight outside the app."
            ),
            WelcomeFeature(
                icon: "chart.line.uptrend.xyaxis",
                title: "Track Your Progress",
                description: "See your streak, mastered words, and daily learning at a glance."
            )
        ],
        signInStep: WelcomeSignInStep(
            hero: .appIcon,
            title: "Sign in to get more",
            features: [
                WelcomeFeature(
                    icon: "icloud.and.arrow.up.fill",
                    title: "Sync Everywhere",
                    description: "Your progress, streaks, and bookmarks stay in sync across your devices."
                ),
                WelcomeFeature(
                    icon: "bookmark.fill",
                    title: "Keep Your Saved Words",
                    description: "Bookmarks and custom lists stay with your account, not the device."
                ),
                WelcomeFeature(
                    icon: "infinity",
                    title: "Higher Daily Limit",
                    description: "Unlock more words per day and keep learning past the free cap."
                )
            ]
        )
    )
}

// MARK: - Persistence

enum WelcomeFeatureTracker {
    static let storageKey = "welcome.lastSeenVersion"

    static var lastSeenVersion: String {
        get { UserDefaults.standard.string(forKey: storageKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    static func shouldShow(_ release: WelcomeRelease) -> Bool {
        lastSeenVersion != release.version
    }

    static func markSeen(_ release: WelcomeRelease) {
        lastSeenVersion = release.version
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - Sheet Modifier

struct WelcomeFeaturesSheetModifier: ViewModifier {
    let release: WelcomeRelease
    let onSignIn: ((WelcomeSignInMethod) -> Void)?
    @State private var isPresented: Bool = false
    /// Stashed until `onDismiss` fires so we present the next sheet only
    /// *after* the welcome sheet is fully off-screen. Presenting two sheets
    /// back-to-back synchronously causes the second one to silently no-op.
    @State private var pendingSignIn: WelcomeSignInMethod? = nil

    func body(content: Content) -> some View {
        content
            .task {
                if WelcomeFeatureTracker.shouldShow(release) {
                    isPresented = true
                }
            }
            .sheet(isPresented: $isPresented, onDismiss: {
                if let method = pendingSignIn {
                    pendingSignIn = nil
                    onSignIn?(method)
                }
            }) {
                WelcomeFlowView(release: release) { method in
                    WelcomeFeatureTracker.markSeen(release)
                    pendingSignIn = method
                    isPresented = false
                }
                .interactiveDismissDisabled()
            }
    }
}

extension View {
    /// Shows the one-time welcome flow. Optional `onSignIn` is invoked *after*
    /// the sheet dismisses when the user chose Apple or Email — present your
    /// full auth sheet in response.
    func welcomeFeaturesSheet(
        for release: WelcomeRelease = WhatsNewManifest.current,
        onSignIn: ((WelcomeSignInMethod) -> Void)? = nil
    ) -> some View {
        modifier(WelcomeFeaturesSheetModifier(release: release, onSignIn: onSignIn))
    }
}

// MARK: - Flow Host

/// Two-page flow: features → optional sign-in benefits. `onComplete` fires
/// with `nil` when the user finished/skipped, or the chosen method.
struct WelcomeFlowView: View {
    let release: WelcomeRelease
    let onComplete: (WelcomeSignInMethod?) -> Void

    private enum Step: Hashable { case signIn }

    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeFeaturesView(release: release) {
                if release.signInStep != nil {
                    path.append(.signIn)
                } else {
                    onComplete(nil)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .signIn:
                    if let signIn = release.signInStep {
                        SignInBenefitsView(step: signIn, onAction: onComplete)
                            .navigationBarHidden(true)
                    }
                }
            }
        }
        .id(ThemeManager.shared.accent)
    }
}

// MARK: - Features Page

struct WelcomeFeaturesView: View {
    let release: WelcomeRelease
    let onContinue: () -> Void

    private var accent: Color { Color.accentPrimary }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroSection(hero: release.hero)

                    Text(release.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(release.features) { feature in
                            WelcomeFeatureRow(feature: feature, defaultTint: accent)
                        }
                    }

                    Spacer(minLength: 32)

                    if let footer = release.footerNote {
                        WelcomeFooterNoteView(note: footer, tint: accent)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryCapsuleButton(title: release.buttonTitle, tint: accent, action: onContinue)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Sign-In Benefits Page

struct SignInBenefitsView: View {
    let step: WelcomeSignInStep
    /// nil = skip/done, else the picked method.
    let onAction: (WelcomeSignInMethod?) -> Void

    private var accent: Color { Color.accentPrimary }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroSection(hero: step.hero)

                    Text(step.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(step.features) { feature in
                            WelcomeFeatureRow(feature: feature, defaultTint: accent)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            buttonStack
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .background(Color(UIColor.systemBackground))
    }

    private var buttonStack: some View {
        VStack(spacing: 10) {
            if step.showApple {
                AuthCapsuleButton(
                    title: step.appleButtonTitle,
                    icon: "apple.logo",
                    background: .color(.black),
                    foreground: .white
                ) {
                    onAction(.apple)
                }
            }

            if step.showEmail {
                AuthCapsuleButton(
                    title: step.emailButtonTitle,
                    icon: "envelope.fill",
                    background: .color(accent),
                    foreground: .white
                ) {
                    onAction(.email)
                }
            }

            if step.allowSkip {
                Button {
                    onAction(nil)
                } label: {
                    Text(step.skipButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Shared Bits

private struct HeroSection: View {
    let hero: WelcomeHero

    var body: some View {
        Group {
            switch hero {
            case .none:
                Color.clear.frame(height: 32)
            case .appIcon:
                AppIconHero()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 56)
            case .symbol(let symbol):
                SymbolTile(systemName: symbol)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 56)
            }
        }
    }
}

private struct SymbolTile: View {
    let systemName: String

    var body: some View {
        let accent = Color.accentPrimary
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 118, height: 118)
                .shadow(color: accent.opacity(0.35), radius: 20, y: 10)

            Image(systemName: systemName)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct PrimaryCapsuleButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tint, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private enum AuthButtonBackground {
    case color(Color)
}

private struct AuthCapsuleButton: View {
    let title: String
    let icon: String
    let background: AuthButtonBackground
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule().fill(backgroundFill)

                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(foreground)
                        .frame(width: 24)
                    Spacer()
                }
                .padding(.horizontal, 20)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(foreground)
            }
            .frame(height: 54)
        }
        .buttonStyle(.plain)
    }

    private var backgroundFill: Color {
        switch background {
        case .color(let color): return color
        }
    }
}

// MARK: - App Icon Hero

private struct AppIconHero: View {
    private let tileSize: CGFloat = 118
    private let cornerRadius: CGFloat = 26

    var body: some View {
        Group {
            if let uiImage = Self.loadAppIcon() {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: tileSize, height: tileSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                SymbolTile(systemName: "books.vertical.fill")
            }
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
    }

    static func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let image = UIImage(named: last) {
            return image
        }
        for name in ["AppIcon", "AppIcon60x60", "AppIcon-60x60", "AppIcon76x76"] {
            if let image = UIImage(named: name) { return image }
        }
        return nil
    }
}

// MARK: - Feature Row

private struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature
    let defaultTint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: feature.icon)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(feature.iconColor ?? defaultTint)
                .frame(width: 36, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(feature.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Footer Note

private struct WelcomeFooterNoteView: View {
    let note: WelcomeFooterNote
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: note.icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 28)

            footerText
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var footerText: Text {
        var text = Text(note.text)
        if let linkText = note.linkText {
            text = text + Text(" ")
            if let url = note.linkURL {
                text = text + Text("[\(linkText)](\(url.absoluteString))")
                    .foregroundColor(tint)
            } else {
                text = text + Text(linkText).foregroundColor(tint)
            }
        }
        return text
    }
}

// MARK: - Preview

#Preview("Welcome Flow (Light)") {
    Color(UIColor.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WelcomeFlowView(release: WhatsNewManifest.current) { _ in }
        }
}

#Preview("Welcome Flow (Dark)") {
    Color(UIColor.systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WelcomeFlowView(release: WhatsNewManifest.current) { _ in }
        }
        .preferredColorScheme(.dark)
}
