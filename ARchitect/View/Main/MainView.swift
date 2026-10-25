//
//  MainView.swift
//  ARchitect
//
//  Created by Songyuan Liu on 2/4/25.
//

import SwiftUI

struct MainView: View {
    @Binding var sharedPostID: String?
    @State private var sharedPost: Post?
    init(sharedPostID: Binding<String?> = .constant(nil)) { _sharedPostID = sharedPostID }

    @StateObject private var session = SessionStore()

    var body: some View {
        RootTabView()
            .task(id: "\(session.isAuthenticated)-\(sharedPostID ?? "")") {
                guard session.isAuthenticated, let uid = session.user?.uid,
                      let id = sharedPostID else { return }
                let fetched = await SocialService.fetchPost(id: id)
                guard !Task.isCancelled, session.user?.uid == uid,
                      sharedPostID == id else { return }
                sharedPost = fetched.flatMap { session.isBlocked($0.authorUid) ? nil : $0 }
                if sharedPost == nil { session.errorMessage = "This shared post is unavailable or could not be loaded." }
                sharedPostID = nil
            }
            .fullScreenCover(item: $sharedPost) { post in
                NavigationStack { PostView(post: post) }.environmentObject(session)
            }
            // App-wide Inter default typography + tint.
            .font(AppFont.body)
            .tint(.appPrimary)
            .environmentObject(session)
            .alert("Could not complete action", isPresented: Binding(get: { session.errorMessage != nil && session.isAuthenticated }, set: { if !$0 { session.errorMessage = nil } })) {
                Button("OK") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
            .sheet(isPresented: Binding(get: {
                !session.isAuthenticated
            }, set: { _ in })) {
                Group {
                    if session.user != nil {
                        ProfileSetupView().environmentObject(session)
                    } else {
                        AuthenticationView().environmentObject(session)
                    }
                }
                    .interactiveDismissDisabled(true)
                    // Sheets get a fresh environment, so apply here too.
                    .font(AppFont.body)
                    .tint(.appPrimary)
            }
    }
}

#Preview {
    MainView()
}

private struct ProfileSetupView: View {
    @EnvironmentObject var session: SessionStore
    @State private var username = ""
    var body: some View {
        VStack(spacing: 20) {
            Text("Setting up your profile").font(.title2)
            if session.isLoadingProfile { ProgressView() }
            if let error = session.errorMessage { Text(error).foregroundStyle(.red) }
            if !session.isLoadingProfile {
                TextField("Username (optional for retry)", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                Button("Try again") { Task { await session.retryProfile(username: username.isEmpty ? nil : username) } }
                Button("Sign out") { session.signOut() }
            }
        }.padding()
    }
}
