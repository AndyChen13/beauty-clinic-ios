//  App.swift
//  BeautyClinic
//
//  Created by Andy Chen on 2026-08-19.
//

import SwiftUI
import Supabase

@main
struct BeautyClinicApp: App {
    // Supabase client - configure with your project credentials
    private let client = SupabaseClient(
        url: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://YOUR_PROJECT.supabase.co",
        apiKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "YOUR_ANON_KEY"
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.supabaseClient, client)
        }
    }
}

// MARK: - Environment Objects

private extension EnvironmentValues {
    @Entry var supabaseClient: SupabaseClient?
}