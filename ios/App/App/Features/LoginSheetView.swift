import SwiftUI

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.webPrimary)
                            .padding(.bottom, Spacing.xs)
                        
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.title2.bold())
                        
                        Text(isSignUp ? "Sign up to track your learning progress." : "Log in to continue your learning journey.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xl)
                    
                    // Form fields
                    VStack(spacing: Spacing.md) {
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 0) {
                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                            
                            Divider()
                            
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                            
                            if isSignUp {
                                Divider()
                                
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                            }
                        }
                        .clipShape(.rect(cornerRadius: 12))
                        
                        // Action Button
                        Button(action: {
                            Task {
                                await authenticate()
                            }
                        }) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Log In")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.webPrimary)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && confirmPassword.isEmpty))
                        .opacity((isLoading || email.isEmpty || password.isEmpty || (isSignUp && confirmPassword.isEmpty)) ? 0.6 : 1.0)
                        
                        // Toggle Button
                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                                .font(.footnote)
                                .foregroundStyle(Color.webPrimary)
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authService.isAuthenticated) {
                if authService.isAuthenticated {
                    dismiss()
                }
            }
        }
    }
    
    private func authenticate() async {
        errorMessage = nil
        
        if isSignUp && password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if isSignUp {
                _ = try await authService.signUp(email: email, password: password)
            } else {
                _ = try await authService.signIn(email: email, password: password)
            }
            // Dismissal is handled by the onChange publisher above
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginSheetView()
}
