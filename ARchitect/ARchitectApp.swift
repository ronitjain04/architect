//
//  ARchitectApp.swift
//  ARchitect
//
//  SwiftUI app entry point. A slim AppDelegate remains (via the adaptor)
//  for Firebase configuration at launch.
//

import SwiftUI
import GoogleSignIn

@main
struct ARchitectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var sharedPostID: String?

    var body: some Scene {
        WindowGroup {
            MainView(sharedPostID: $sharedPostID)
                // Google Sign-In redirect callback.
                .onOpenURL { url in
                    if let id = RoomLink.postID(from: url) { sharedPostID = id }
                    else { _ = GIDSignIn.sharedInstance.handle(url) }
                }
        }
    }
}
