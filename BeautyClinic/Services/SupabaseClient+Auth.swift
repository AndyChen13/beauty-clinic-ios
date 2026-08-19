// SupabaseClient+Auth.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import Supabase

extension SupabaseClient {
    func signOut() async throws {
        try await auth.signOut()
    }
}