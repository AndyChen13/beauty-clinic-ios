// App.swift
import SwiftUI

// MARK: - Global User State (replaces Supabase auth)
@MainActor
class UserState: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var pendingUserCount: Int = 0
    
    var isAdmin: Bool { currentUser?.isAdmin ?? false }
    var isSuperAdmin: Bool { currentUser?.isSuperAdmin ?? false }
    var storeId: UUID? { currentUser?.storeId }
    
    func loadUser() async {
        isLoading = true
        defer { isLoading = false }
        
        // Check if we have a stored token
        guard APIConfig.authToken != nil else {
            currentUser = nil
            return
        }
        
        do {
            try await AuthService.shared.loadUser()
            currentUser = AuthService.shared.currentUser
            if currentUser?.isSuperAdmin == true {
                await checkPendingApprovals()
            }
        } catch {
            print("Failed to load user: \(error)")
            APIConfig.authToken = nil
            currentUser = nil
        }
    }
    
    func checkPendingApprovals() async {
        guard currentUser?.isSuperAdmin == true else { return }
        do {
            let users = try await AdminService.shared.listPendingUsers()
            pendingUserCount = users.count
        } catch {
            print("检查待审批用户失败: \(error)")
        }
    }
    
    func signOut() {
        AuthService.shared.signOut()
        currentUser = nil
        pendingUserCount = 0
    }
}

@main
struct BeautyManagerApp: App {
    @StateObject private var userState = UserState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userState)
        }
    }
}
