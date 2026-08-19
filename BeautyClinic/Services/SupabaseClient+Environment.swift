// SupabaseClient+Environment.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

extension View {
    func supabaseClient(_ client: SupabaseClient?) -> some View {
        environment(\.supabaseClient, client)
    }
}