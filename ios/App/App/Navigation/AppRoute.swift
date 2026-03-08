import SwiftUI

// MARK: - App Route

/// Type-safe navigation destinations used across the app.
///
/// Centralises all deep-link and programmatic navigation into a single `Hashable` enum
/// so every `NavigationStack` can share the same `NavigationPath` and
/// `.navigationDestination(for:)` resolution.
enum AppRoute: Hashable {
    /// Show the detail view for a specific word.
    case wordDetail(Word)
}

// MARK: - Navigation Destination Resolver

extension View {
    /// Registers all `AppRoute` navigation destinations for a `NavigationStack`.
    ///
    /// Apply this once inside each `NavigationStack` to get consistent, type-safe
    /// routing throughout the app.
    ///
    /// ```swift
    /// NavigationStack {
    ///     content
    ///         .withAppRoutes()
    /// }
    /// ```
    func withAppRoutes() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .wordDetail(let word):
                WordDetailView(word: word)
            }
        }
    }
}
