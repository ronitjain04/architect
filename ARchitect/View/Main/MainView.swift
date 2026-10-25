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
        Group {
            if session.isAuthenticated {
                RootTabView()
            } else if session.isResolvingSession || session.isLoadingProfile {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    ProgressView("Opening your space…")
                        .tint(.appPrimary)
                        .foregroundStyle(Color.appText)
                }
            } else if session.user != nil {
                ProfileSetupView()
            } else {
                AuthenticationView()
            }
        }
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
            .onReceive(NotificationCenter.default.publisher(for: .ownPostDeleted)) { _ in
                sharedPost = nil
            }
            // App-wide Inter default typography + tint.
            .font(AppFont.body)
            .tint(.appPrimary)
            .environmentObject(session)
            .alert("Could not complete action", isPresented: Binding(get: { session.errorMessage != nil && session.isAuthenticated }, set: { if !$0 { session.errorMessage = nil } })) {
                Button("OK") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
    }
}

#Preview {
    MainView()
}

private struct ProfileSetupView: View {
    @EnvironmentObject var session: SessionStore
    @State private var username = ""
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(Color.appPrimary)
                Text("Your profile needs a moment")
                    .font(AppFont.title)
                    .foregroundStyle(Color.appText)
                Text("We couldn't finish loading your profile. Check your connection and try again.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.appTextSecondary)
                if let error = session.errorMessage {
                    Text(error)
                        .font(AppFont.callout)
                        .foregroundStyle(Color.appLike)
                }
                TextField("Username (only if you need a new one)", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.md)
                    .background(Color.appSurfaceAlt, in: RoundedRectangle(cornerRadius: AppRadius.md))
                Button("Try again") {
                    Task { await session.retryProfile(username: username.isEmpty ? nil : username) }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Sign out") { session.signOut() }
                    .font(AppFont.button)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.appPrimary)
                Spacer()
            }
            .padding(AppSpacing.lg)
            .padding(.top, 90)
        }
    }
}
