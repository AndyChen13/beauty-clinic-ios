//  Views/ContentView.swift
//  BeautyClinic
//

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isChecking = true
    
    var body: some View {
        Group {
            if isChecking {
                SplashScreen()
            } else if isAuthenticated {
                MainTabView()
            } else {
                LoginView(onLoginSuccess: { isAuthenticated = true })
            }
        }
        .onAppear { checkAuth() }
    }
    
    private func checkAuth() {
        Task {
            do {
                let session = try await supabase.auth.session
                isAuthenticated = !session.accessToken.isEmpty
            } catch {
                isAuthenticated = false
            }
            isChecking = false
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                )
            Text("Beauty Clinic")
                .font(.largeTitle.weight(.bold))
            Text("内部管理系统")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView()
                .padding(.top, 20)
        }
    }
}

#Preview {
    ContentView()
}
