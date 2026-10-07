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
    static func signIn(completion: @escaping (Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(NSError(domain: "ARchitect", code: 1, userInfo: [NSLocalizedDescriptionKey: "Google sign-in is not configured."]))
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else {
            completion(NSError(domain: "ARchitect", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to present Google sign-in."]))
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                completion(error)
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                completion(NSError(domain: "ARchitect", code: 3, userInfo: [NSLocalizedDescriptionKey: "Google did not return a valid sign-in token."]))
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    completion(error)
                    return
                }


                completion(nil)
            }
        }
    }
}
