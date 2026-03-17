import SwiftUI

// MARK: - Edit Profile View
// A form-based view for editing user profile information.
// Allows users to update their display name while keeping email read-only.

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var displayName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showSuccessMessage = false

    private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.adaptiveBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Form Content
                        VStack(spacing: Spacing.md) {
                            // Display Name Field
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Display Name")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                TextField("Display Name", text: $displayName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.body)
                                    .disabled(isLoading)
                                    .padding(.bottom, Spacing.sm)
                            }

                            // Email Field (Read-only)
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Email")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(authService.currentUser?.email ?? "")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.adaptiveCardBackground)
                                    )
                                    .opacity(0.6)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.adaptiveCardBackground)
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)

                        // Error Message
                        if let errorMessage = errorMessage {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)

                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .padding(.horizontal, Spacing.md)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Success Message
                        if showSuccessMessage, let successMessage = successMessage {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)

                                Text(successMessage)
                                    .font(.caption)
                                    .foregroundStyle(.green)

                                Spacer()
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                            .padding(.horizontal, Spacing.md)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.webPrimary)
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                    } else {
                        Button("Save") {
                            saveProfile()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.webPrimary)
                        .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            // Pre-fill display name from email prefix
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

                // Dismiss after a short delay
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

        // Supabase user_metadata for custom fields
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
