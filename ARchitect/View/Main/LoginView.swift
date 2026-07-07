//
//  LoginView.swift
//  ARchitect
//
//  Instagram-style log in screen, consistent with AuthenticationView.
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @Binding var isAuthenticated: Bool

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: AppSpacing.xs) {
                    Text("ARchitect")
                        .font(AppFont.fraunces(40, .semibold))
                        .foregroundColor(.appText)
                    Text("Welcome back")
                        .font(AppFont.inter(13, .regular))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.bottom, AppSpacing.xl)

                VStack(spacing: AppSpacing.sm) {
                    AuthField(placeholder: "Username", text: $username)
                    AuthField(placeholder: "Password", text: $password, isSecure: true)
                }

                Button("Forgot password?") { }
                    .font(AppFont.inter(12, .medium))
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, AppSpacing.sm)

                Button("Log in") {
                    isAuthenticated = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppSpacing.md)

                HStack(spacing: AppSpacing.sm) {
                    Rectangle().fill(Color.appDivider).frame(height: 1)
                    Text("OR").font(AppFont.inter(11, .semibold)).foregroundColor(.appTextSecondary)
                    Rectangle().fill(Color.appDivider).frame(height: 1)
                }
                .padding(.vertical, AppSpacing.lg)

                Button {
                    GoogleAuthService.signIn { isAuthenticated = true }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "g.circle.fill").font(.system(size: 18))
                        Text("Continue with Google").font(AppFont.inter(14, .semibold))
                    }
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .stroke(Color.appPrimary.opacity(0.4), lineWidth: 1.5)
                    )
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xl)
        }
    }
}

#Preview {
    LoginView(isAuthenticated: .constant(false))
}
