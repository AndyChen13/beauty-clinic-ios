// Views/ContentView.swift
import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var userState: UserState
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if userState.isLoading {
                SplashScreen()
            } else if isAuthenticated, userState.currentUser != nil {
                MainTabView()
                    .environmentObject(userState)
            } else {
                AuthView(onAuthSuccess: {
                    Task {
                        await userState.loadUser()
                        isAuthenticated = true
                    }
                })
            }
        }
        .onAppear { checkAuth() }
    }
    
    private func checkAuth() {
        Task {
            #if DEBUG
            // DEBUG 模式：自动注入 mock admin 用户，跳过登录
            let mockUser = User(
                id: UUID(),
                email: "admin@beautyclinic.com",
                phone: nil,
                name: "管理员",
                role: .admin,
                storeId: nil,
                avatarUrl: nil,
                createdAt: nil,
                updatedAt: nil
            )
            await MainActor.run {
                userState.currentUser = mockUser
                userState.isLoading = false
                isAuthenticated = true
            }
            #else
            do {
                let session = try await supabase.auth.session
                if !session.accessToken.isEmpty && !session.isExpired {
                    await userState.loadUser()
                    isAuthenticated = true
                } else {
                    isAuthenticated = false
                }
            } catch {
                isAuthenticated = false
            }
            await MainActor.run {
                userState.isLoading = false
            }
            #endif
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
        .environmentObject(UserState())
}
