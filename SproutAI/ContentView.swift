//
//  ContentView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService()
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()
                
            switch authService.authState {
            case .checking:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            case .unauthenticated:
                LoginView(authService: authService)
            case .authenticated:
                DashboardView(authService: authService)
            }
        }
    }
}

#Preview {
    ContentView()
}
