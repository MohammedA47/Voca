import SwiftUI

// MARK: - Edit Profile View
// A form-based view for editing user profile information.
// Presented as a sheet with Cancel/Save — keeps its own NavigationStack.

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showSuccessMessage = false

    private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SettingsCloseButton {
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
                guard let sessionToken = authService.sessionToken else {
                    throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active session"])
                }

                try await updateUserProfile(displayName: trimmedDisplayName, token: sessionToken)

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

    // MARK: - API Call

    private func updateUserProfile(displayName: String, token: String) async throws {
        let supabaseUrl = "https://brknoeqgpejhxsqsjnan.supabase.co"
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/user") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let metadata: [String: Any] = ["display_name": displayName]
        let body: [String: Any] = ["user_metadata": metadata]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Auth API Update Profile failed with status \(httpResponse.statusCode): \(errorBody)")

            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errorDict["msg"] as? String {
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Preview
#Preview {
    EditProfileView()
}
