import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

struct AuthenticationView: View {
	@Binding var isAuthenticated: Bool
	@State private var isHighlighted = false
	@State private var rectangleColor: Color = Color("FFF2DF")
	@State private var textColor: Color = Color("635346")

	var body: some View {
		NavigationStack {
			ZStack {
				Color("#FFF2DF")
						.ignoresSafeArea()
				VStack {
					Spacer().frame(height: 40)
					HStack {
						ZStack {
							RoundedRectangle(cornerRadius: 5)
								.fill(rectangleColor)
								.frame(width: 100, height: 100)
								.animation(.easeInOut(duration: 2), value: rectangleColor)
								.cornerRadius(20)
							Text("AR")
								.font(.system(size: 75, design: .rounded))
								.foregroundColor(textColor)
								.animation(.easeInOut(duration: 2), value: textColor)
						}
						Text("chitect")
							.font(.system(size: 75, weight: .light, design: .rounded))
							.foregroundColor(Color("635346"))
					}
					.frame(maxHeight: .infinity, alignment: .top)
					.padding()
					Image("landingIcon")
					VStack(spacing: 12) {
                        Text("Login")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color("FFF2DF"))
                            .padding()
                            .frame(width: 346, height: 56)
                            .background(Color("635346"))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15).stroke(Color("635346"), lineWidth: 2)
                            )
                            .onTapGesture {
                                isAuthenticated = true
                            }
						.padding()
						NavigationLink(destination: SignUpView(isAuthenticated: $isAuthenticated)) {
							Text("Sign Up")
								.font(.system(size: 20, weight: .bold, design: .rounded))
								.foregroundColor(Color("635346"))
								.padding()
								.frame(width: 346, height: 56)
								.background(Color("FFF2DF"))
								.cornerRadius(15)
								.overlay(
									RoundedRectangle(cornerRadius: 15).stroke(Color("635346"), lineWidth: 2)
								)
						}
					}
					.padding()
					VStack(spacing: 16) {
						HStack {
							Rectangle()
								.fill(Color("#A0907C"))
								.frame(height: 1)
							Text("or continue with")
								.font(.system(size: 16, design: .rounded))
								.foregroundColor(Color( "#A0907C"))
							Rectangle()
								.fill(Color("#A0907C"))
								.frame(height: 1)
						}
						.padding(.horizontal)
						HStack(spacing: 16) {
							socialButton(label: "Google", iconName: "g.circle.fill") {
								googleSignIn()
							}
							socialButton(label: "Apple", iconName: "apple.logo") {
								//handle Apple Sign In
							}
						}
					}
					Spacer().frame(height: 50)
				}
			}
		}
		.onAppear {
			startColorChangeTimer()
		}
	}

	func startColorChangeTimer() {
		Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
			isHighlighted.toggle()
			rectangleColor = isHighlighted ? Color("635346") : Color("FFF2DF")
			textColor = isHighlighted ? Color("FFF2DF") : .black
		}
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
	
	// Button View
	func socialButton(label: String, iconName: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack(spacing: 8) {
				Image(systemName: iconName)
					.font(.system(size: 20))
				Text(label)
					.font(.system(size: 18, weight: .medium))
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 10)
			.foregroundColor(Color("635346"))
			.frame(width: 170, height: 50)
			.overlay(
				RoundedRectangle(cornerRadius: 15)
					.stroke(Color("634346"), lineWidth: 2)
			)
			.background(Color.clear)
			//.clipShape(RoundedRectangle(cornerRadius: 20))
		}
	}
	
}

#Preview {
	AuthenticationView(isAuthenticated: .constant(false))
}
