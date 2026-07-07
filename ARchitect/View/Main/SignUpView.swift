//
//  SignUpView.swift
//  ARchitect
//
//  Instagram-style sign up backed by Firebase: wordmark, soft fields, a
//  primary action, and a "log in" link at the bottom.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var isValid: Bool {
        !username.isEmpty && !email.isEmpty && password.count >= 6
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.appText)
                    }
                    Spacer()
                }

                Spacer()

                VStack(spacing: AppSpacing.xs) {
                    Text("ARchitect")
                        .font(AppFont.fraunces(36, .semibold))
                        .foregroundColor(.appText)
                    Text("Sign up to design and share your spaces")
                        .font(AppFont.inter(13, .regular))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, AppSpacing.xl)

                VStack(spacing: AppSpacing.sm) {
                    AuthField(placeholder: "Username", text: $username)
                    AuthField(placeholder: "Email", text: $email, keyboard: .emailAddress)
                    AuthField(placeholder: "Password (6+ characters)", text: $password, isSecure: true)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppFont.inter(12, .medium))
                        .foregroundColor(.appLike)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.sm)
                }

                Button {
                    signUp()
                } label: {
                    if isLoading {
                        ProgressView().tint(.appOnPrimary)
                    } else {
                        Text("Sign up")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading || !isValid)
                .opacity(isValid ? 1 : 0.6)
                .padding(.top, AppSpacing.md)

                Text("By signing up, you agree to our Terms and Privacy Policy.")
                    .font(AppFont.inter(11, .regular))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.md)

                Spacer()

                Divider().background(Color.appDivider)

                Button { dismiss() } label: {
                    (Text("Have an account? ").foregroundColor(.appTextSecondary)
                     + Text("Log in").foregroundColor(.appAccent))
                        .font(AppFont.inter(13, .medium))
                }
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func signUp() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await session.signUp(username: username, email: email, password: password)
                // Success dismisses the auth sheet via the auth-state listener.
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(SessionStore())
}
