import SwiftUI

struct ContentView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                LoginView()
                    .onAppear { checkAuthentication() }
            }
        }
        .onChange(of: supabaseClient?.session) { _, _ in
            checkAuthentication()
        }
    }
    
    private func checkAuthentication() {
        guard let client = supabaseClient,
              client.session != nil else { return }
        isAuthenticated = true
    }
}

#Preview {
    ContentView()
}