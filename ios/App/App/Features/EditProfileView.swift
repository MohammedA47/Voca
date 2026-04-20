import SwiftUI

// MARK: - Edit Profile View
// A form-based view for editing user profile information.
// Pushed from AccountSettingsView inside the shared settings NavigationStack.

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showSuccessMessage = false

    private var authService = AuthService.shared

    var body: some View {
        List {
            // ── Profile Fields ──────────────────────────
            Section(header: Text("Profile")) {
                HStack {
                    Text("Name")
                        .font(.body)
                    Spacer()
                    TextField("Display Name", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .disabled(isLoading)
                }

                HStack {
                    Text("Email")
                        .font(.body)
                    Spacer()
                    Text(authService.currentUser?.email ?? "")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Status Messages ─────────────────────────
            if let errorMessage = errorMessage {
                Section {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
            }

            if showSuccessMessage, let successMessage = successMessage {
                Section {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(successMessage)
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
                .disabled(isLoading)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .tertiarySystemFill))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                } else {
                    SettingsToolbarCircleButton(
                        systemName: "checkmark",
                        accessibilityLabel: "Save",
                        iconSize: 16,
                        weight: .semibold
                    ) {
                        saveProfile()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            let emailPrefix = authService.currentUser?.email?.components(separatedBy: "@").first ?? "User"
            displayName = emailPrefix.capitalized
        }
    }

    // MARK: - Save Profile

    private func saveProfile() {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        guard !trimmedDisplayName.isEmpty else {
            errorMessage = "Display name cannot be empty"
            return
        }

        isLoading = true
        errorMessage = nil
        showSuccessMessage = false

        Task {
            do {
                try await authService.updateProfile(displayName: trimmedDisplayName)

                successMessage = "Profile updated successfully!"
                showSuccessMessage = true

                try await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        EditProfileView()
    }
}
