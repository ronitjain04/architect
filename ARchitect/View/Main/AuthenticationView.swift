import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

/// The entry/login screen — an Instagram-style centered layout: a serif
/// wordmark, soft cream fields, a primary "Log in" action, a Google option,
/// and a sign-up link pinned to the bottom.
struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var username: String = ""
    @State private var password: String = ""

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
                        googleSignIn()
                    }

                    Spacer()

                    Divider().background(Color.appDivider)

                    NavigationLink {
                        SignUpView(isAuthenticated: $isAuthenticated)
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

    func googleSignIn() {
        GoogleAuthService.signIn {
            isAuthenticated = true
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

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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
    AuthenticationView(isAuthenticated: .constant(false))
}
