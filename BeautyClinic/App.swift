// App.swift
import SwiftUI

// MARK: - Global User State (replaces Supabase auth)
@MainActor
class UserState: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    
    var isAdmin: Bool { currentUser?.isAdmin ?? false }
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
        } catch {
            print("Failed to load user: \(error)")
            APIConfig.authToken = nil
            currentUser = nil
        }
    }
    
    func signOut() {
        AuthService.shared.signOut()
        currentUser = nil
    }
}

@main
struct BeautyClinicApp: App {
    @StateObject private var userState = UserState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userState)
        }
    }
}
