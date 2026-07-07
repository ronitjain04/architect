import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

/// The entry/login screen — an Instagram-style centered layout: a serif
/// wordmark, soft cream fields, a primary "Log in" action, a Google option,
/// and a sign-up link pinned to the bottom. Backed by real Firebase auth.
struct AuthenticationView: View {
    @EnvironmentObject var session: SessionStore
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Wordmark
                    VStack(spacing: AppSpacing.xs) {
                        Text("ARchitect")
                            .font(AppFont.fraunces(40, .semibold))
                            .foregroundColor(.appText)
                        Text("Design your space in AR")
                            .font(AppFont.inter(13, .regular))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.bottom, AppSpacing.xl)

                    // Fields
                    VStack(spacing: AppSpacing.sm) {
                        AuthField(placeholder: "Email", text: $email, keyboard: .emailAddress)
                        AuthField(placeholder: "Password", text: $password, isSecure: true)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.inter(12, .medium))
                            .foregroundColor(.appLike)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, AppSpacing.sm)
                    }

                    Button("Forgot password?") {
                        sendPasswordReset()
                    }
                    .font(AppFont.inter(12, .medium))
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, AppSpacing.sm)

                    Button {
                        logIn()
                    } label: {
                        if isLoading {
                            ProgressView().tint(.appOnPrimary)
                        } else {
                            Text("Log in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    .padding(.top, AppSpacing.md)

                    // Divider
                    HStack(spacing: AppSpacing.sm) {
                        line
                        Text("OR")
                            .font(AppFont.inter(11, .semibold))
                            .foregroundColor(.appTextSecondary)
                        line
                    }
                    .padding(.vertical, AppSpacing.lg)

                    socialButton(label: "Continue with Google", iconName: "g.circle.fill") {
                        session.signInWithGoogle()
                    }

                    Spacer()

                    Divider().background(Color.appDivider)

                    NavigationLink {
                        SignUpView()
                    } label: {
                        (Text("Don't have an account? ").foregroundColor(.appTextSecondary)
                         + Text("Sign up").foregroundColor(.appAccent))
                            .font(AppFont.inter(13, .medium))
                    }
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.xl)
            }
        }
    }

    private var line: some View {
        Rectangle().fill(Color.appDivider).frame(height: 1)
    }

    private func logIn() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await session.logIn(email: email, password: password)
                // Success dismisses the sheet via the auth-state listener.
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func sendPasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "Enter your email above first, then tap Forgot password."
            return
        }
        errorMessage = nil
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                errorMessage = "Password reset email sent to \(email)."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func socialButton(label: String, iconName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName).font(.system(size: 18))
                Text(label).font(AppFont.inter(14, .semibold))
            }
            .foregroundColor(.appPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(Color.appPrimary.opacity(0.4), lineWidth: 1.5)
            )
        }
    }
}

/// Soft, filled text field used across the auth screens.
struct AuthField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(keyboard)
            }
        }
        .font(AppFont.body)
        .foregroundColor(.appText)
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color.appSurfaceAlt)
        )
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(SessionStore())
}
