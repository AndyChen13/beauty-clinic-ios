//  App.swift
//  BeautyClinic
//
//  Created by Andy Chen on 2026-08-19.
//

import SwiftUI
import Supabase

// MARK: - Supabase Configuration
// Replace with your actual Supabase project credentials
private let supabaseURL = URL(string: "https://ugwhgxtutochaodgrrqn.supabase.co")!
private let supabaseKey = "sb_publishable_a0iYjlquj72R2J06tZwzGA_1n1Cy_lv"

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseKey
)

@main
struct BeautyClinicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
