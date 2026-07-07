//
//  SignUpView.swift
//  ARchitect
//
//  Instagram-style sign up: wordmark, soft fields, a primary action, and a
//  "log in" link at the bottom.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @Binding var isAuthenticated: Bool

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
                    AuthField(placeholder: "Email", text: $email)
                    AuthField(placeholder: "Password", text: $password, isSecure: true)
                }

                Button("Sign up") {
                    isAuthenticated = true
                }
                .buttonStyle(PrimaryButtonStyle())
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
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}
