// App.swift
import SwiftUI
import Supabase

// MARK: - Supabase Configuration
private let supabaseURL = URL(string: "https://ugwhgxtutochaodgrrqn.supabase.co")!
private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnd2hneHR1dG9jaGFvZGdycnFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNTk3MzIsImV4cCI6MjEwMjczNTczMn0.2kfp-9EwutEyysxIcpINo1eApQn44oTA29qsbETEs7g"

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseKey,
    options: .init(
        auth: .init(
            emitLocalSessionAsInitialSession: true
        )
    )
)

// MARK: - Global User State
@MainActor
class UserState: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = true
    
    var isAdmin: Bool { currentUser?.isAdmin ?? false }
    var storeId: UUID? { currentUser?.storeId }
    
    func loadUser() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await supabase.auth.user()
            let users: [User] = try await supabase
                .from("users")
                .select()
                .eq("id", value: user.id)
                .execute()
                .value
            currentUser = users.first
        } catch {
            print("Failed to load user: \(error)")
            currentUser = nil
        }
    }
    
    func signOut() async {
        try? await supabase.auth.signOut()
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
