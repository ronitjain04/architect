//
//  MainView.swift
//  ARchitect
//
//  Created by Songyuan Liu on 2/4/25.
//

import SwiftUI

struct MainView: View {
    @State private var isAuthenticated: Bool = false
    @State private var selectedTab = 0
    
    
    var body: some View {
        tabController
            .sheet(isPresented: Binding(get: {
                !isAuthenticated
            }, set: { _ in })) {
                AuthenticationView(isAuthenticated: $isAuthenticated)
                    .interactiveDismissDisabled(true)
            }
    }
    
    var tabController: some View {
        GeneralView()
//        BottomNavigationBar()
    }
}

#Preview {
    MainView()
}
