//
//  MainView.swift
//  ARchitect
//
//  Created by Songyuan Liu on 2/4/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var session = SessionStore()

    var body: some View {
        RootTabView()
            // App-wide Inter default typography + tint.
            .font(AppFont.body)
            .tint(.appPrimary)
            .environmentObject(session)
            .sheet(isPresented: Binding(get: {
                !session.isAuthenticated
            }, set: { _ in })) {
                AuthenticationView()
                    .environmentObject(session)
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
