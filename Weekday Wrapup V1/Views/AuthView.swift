import SwiftUI

/// FILE: Views/AuthView.swift
/// Email/password sign up and sign in.
struct AuthView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("SO: Share Openly")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 32)

                    Text(isSignUp ? "Create an account" : "Welcome back")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if isSignUp {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.words)
                    }

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)

                    if let err = auth.authError, !err.isEmpty {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            if isSignUp {
                                await auth.signUp(email: email, password: password, name: name)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Text(isSignUp ? "Sign up" : "Log in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!formValid)

                    Button {
                        isSignUp.toggle()
                        auth.authError = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Log in" : "Need an account? Sign up")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)

                    #if DEBUG
                    Divider()
                        .padding(.top, 4)

                    DebugUserSwitcher()
                        .environmentObject(auth)
                    #endif
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var formValid: Bool {
        let emailOK = email.contains("@") && email.count > 3
        let passOK = password.count >= 6
        if isSignUp {
            return emailOK && passOK && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return emailOK && passOK
    }
}

#if DEBUG
private struct DebugUserSwitcher: View {
    @EnvironmentObject private var auth: AuthManager

    private let testUser1 = (email: "testuser1@weekday.app", password: "Test1234!")
    private let testUser2 = (email: "testuser2@weekday.app", password: "Test1234!")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Debug user switcher")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Login as TestUser1") {
                    Task { await auth.signIn(email: testUser1.email, password: testUser1.password) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("debug_login_user1")

                Button("Login as TestUser2") {
                    Task { await auth.signIn(email: testUser2.email, password: testUser2.password) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("debug_login_user2")
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

#if DEBUG
#Preview("Sign in") {
    AuthViewPreviewHost()
}

private struct AuthViewPreviewHost: View {
    @StateObject private var auth = AuthManager(previewLoggedIn: false)

    var body: some View {
        AuthView()
            .environmentObject(auth)
    }
}
#endif

