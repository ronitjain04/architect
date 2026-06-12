//
//  GoogleAuthService.swift
//  ARchitect
//
//  Single source of truth for Google -> Firebase sign-in.
//  Used by both AuthenticationView and LoginView so the flow isn't duplicated.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

enum GoogleAuthService {
    /// Presents the Google Sign-In sheet and, on success, authenticates with Firebase.
    /// - Parameter onSuccess: called on the main thread once Firebase auth completes.
    static func signIn(onSuccess: @escaping () -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Client ID not found")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("No root view controller found")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                print("Google Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                print("No valid ID token")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase authentication failed: \(error.localizedDescription)")
                    return
                }

                print("User signed in with Google: \(authResult?.user.displayName ?? "Unknown")")
                onSuccess()
            }
        }
    }
}
