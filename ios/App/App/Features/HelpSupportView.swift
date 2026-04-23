import SwiftUI

// MARK: - Help & Support View
// A comprehensive help screen featuring FAQ, contact information, and app version details.
// Pushed via NavigationLink from AccountSheetView — inherits parent NavigationStack.

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var faqExpanded: [Bool] = Array(repeating: false, count: 5)
    @State private var showWhatsNew: Bool = false

    var body: some View {
        List {
            // ── FAQ Section ────────────────────────────────
            faqSection

            // ── Contact Section ────────────────────────────
            contactSection

            // ── App Info Section ───────────────────────────
            appInfoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WelcomeFlowView(release: WhatsNewManifest.current) { _ in
                showWhatsNew = false
            }
        }
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        Section(header: Text("Frequently Asked Questions")) {
            DisclosureGroup(isExpanded: $faqExpanded[0]) {
                Text("Browse words by CEFR level (A1–C1) using the card deck on the Home tab. Tap a card to flip it and see the definition, or swipe to move to the next word.") // C2 commented out
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.sm)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, alignment: .center)

                    Text("How do I learn new words?")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }

            DisclosureGroup(isExpanded: $faqExpanded[1]) {
                Text("Tap the speaker icon on any word card to hear it pronounced. You can choose between US and UK pronunciation in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.sm)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, alignment: .center)

                    Text("How does pronunciation work?")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }

            DisclosureGroup(isExpanded: $faqExpanded[2]) {
                Text("Words are categorized using the CEFR framework: A1-A2 (beginner), B1-B2 (intermediate), C1 (advanced). Start at your comfort level and work up.") // C2 commented out
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.sm)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, alignment: .center)

                    Text("What do the levels mean?")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }

            DisclosureGroup(isExpanded: $faqExpanded[3]) {
                Text("Mark words as learned using the checkmark button. Visit the Stats tab to see your overall progress and learning streak.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.sm)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, alignment: .center)

                    Text("How do I track my progress?")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }

            DisclosureGroup(isExpanded: $faqExpanded[4]) {
                Text("Yes! Tap the bookmark icon on any word card. All bookmarked words appear in your Saved tab.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.sm)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, alignment: .center)

                    Text("Can I save words for later?")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        Section(header: Text("Get in Touch")) {
            Link(destination: URL(string: "mailto:support@oxfordpronunciation.app")!) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.blue)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Contact Support")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("support@oxfordpronunciation.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section(header: Text("App Information")) {
            HStack {
                Text("Version")
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(appVersion)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.xs / 2)

            Button {
                showWhatsNew = true
            } label: {
                HStack {
                    Text("Build")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(appBuild)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.vertical, Spacing.xs / 2)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
