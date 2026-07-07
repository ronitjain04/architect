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

    var body: some Scene {
        WindowGroup {
            MainView()
                // Google Sign-In redirect callback.
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
