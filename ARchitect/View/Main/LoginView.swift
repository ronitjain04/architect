//
//  LoginView.swift
//  ARchitect
//
//

import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseAuth



struct LoginView: View {
	
	struct GoogleSignInButtonView: UIViewRepresentable {
		func makeUIView(context: Context) -> GIDSignInButton {
			let button = GIDSignInButton()
			return button
		}

		func updateUIView(_ uiView: GIDSignInButton, context: Context) {
			// No updates needed
		}
	}

	@State private var username: String = ""
	@State private var password: String = ""
	@Binding var isAuthenticated: Bool
	
	var body: some View {
		VStack(alignment: .leading) {
			Spacer().frame(height: 100)
			HStack {
				Text("Login").font(.system(size:40, weight: .bold, design: .monospaced))
					.padding(.leading)
				Spacer().frame(width: 200)
			}
			Spacer().frame(height: 100)
			VStack(alignment: .leading) {
				Text("Username")
					.font(.system(size:20, design: .monospaced))
					.foregroundColor(.black)
				
				TextField("", text: $username)
					.textFieldStyle(.plain)
					.padding(.vertical, 2)
					.overlay(Rectangle().frame(height: 1).foregroundColor(.gray), alignment: .bottom)
			}
			.padding()
			VStack(alignment: .leading) {
				Text("Password")
					.font(.system(size:20, design: .monospaced))
					.foregroundColor(.black)
				
				SecureField("", text: $password)
					.textFieldStyle(.plain)
					.padding(.vertical, 2)
					.overlay(Rectangle().frame(height: 1).foregroundColor(.gray), alignment: .bottom)
			}
			.padding(.horizontal)
			HStack {
				Spacer().frame(width: 230)
				Button(action: {
					
				}) {
					Text("Forgot Password?").font(.system(size:20, weight: .light))
						.foregroundColor(.gray)
				}
			}
			.padding(.vertical)
			Spacer().frame(height: 70)
			HStack {
				Spacer()
				Button(action: {
					isAuthenticated = true // for testing purpose
					print("Welcome \(username), your password is \(password)")
				}) {
					Text("Login")
						.font(.system(size: 20, design: .monospaced))
						.foregroundColor(.white)
						.padding()
						.frame(width: 350, height: 50)
						.background(Color.black)
						.cornerRadius(15)
				}
				Spacer()
			}
			Spacer()
			HStack {
				Spacer()
				GoogleSignInButtonView()
					.frame(width: 350, height: 50)
					.onTapGesture {
						googleSignIn()
					}
				Spacer()
			}
			Spacer().frame(height: 250)
		}
		.frame(maxHeight: .infinity, alignment: .leading)
	}
	
	func googleSignIn() {
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
			
			let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
			
			Auth.auth().signIn(with: credential) { authResult, error in
				if let error = error {
					print("Firebase authentication failed: \(error.localizedDescription)")
					return
				}
				
				print("User signed in with Google: \(authResult?.user.displayName ?? "Unknown")")
				isAuthenticated = true // Set authentication flag to true

				print("Firebase Authentication successful!")
			}
		}
	}

}


#Preview {
	LoginView(isAuthenticated: .constant(false))
}
