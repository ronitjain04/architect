//
//  SignUpView.swift
//  ARchitect
//
//  Created by Preyas Joshi on 2/20/25.
//

import SwiftUI

struct SignUpView: View {
	@State private var username: String = ""
	@State private var password: String = ""
	@State private var email: String = ""
    @Binding var isAuthenticated: Bool
    
	var body: some View {
		VStack(alignment: .leading) {
			Spacer().frame(height: 50)
			HStack {
				Text("Create a New Account").font(.system(size:30, weight: .bold, design: .monospaced))
					.padding(.leading)
				Spacer().frame(width: 30)
			}
			Spacer().frame(height: 50)
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
				Text("Email")
					.font(.system(size:20, design: .monospaced))
					.foregroundColor(.black)
				
				TextField("", text: $email)
					.textFieldStyle(.plain)
					.padding(.vertical, 2)
					.overlay(Rectangle().frame(height: 1).foregroundColor(.gray), alignment: .bottom)
			}
			.padding()
			VStack(alignment: .leading) {
				Text("Password")
					.font(.system(size:20, design: .monospaced))
					.foregroundColor(.black)
				
				TextField("", text: $password)
					.textFieldStyle(.plain)
					.padding(.vertical, 2)
					.overlay(Rectangle().frame(height: 1).foregroundColor(.gray), alignment: .bottom)
			}
			.padding()
			Spacer()
			HStack {
				Spacer()
				Button(action: {
                    isAuthenticated = true
					print("Welcome \(username), your password is \(password), your email is \(email)")
				}) {
					Text("Sign Up")
						.font(.system(size:20, design: .monospaced))
						.foregroundColor(.black)
						.padding()
						.frame(width: 346, height: 46)
						.background(Color.white) // Button background color
						.cornerRadius(15)
						.overlay(
							RoundedRectangle(cornerRadius: 15).stroke(Color.black, lineWidth: 2) // Black outline
						)
				}
				Spacer()
			}
			Spacer().frame(height: 250)
		}
		.frame(maxHeight: .infinity, alignment: .leading)
	}
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}
