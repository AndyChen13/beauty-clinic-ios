// SupabaseClient.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import Supabase

struct SupabaseClient: Sendable {
    let url: String
    let apiKey: String
    
    init(url: String, apiKey: String) {
        self.url = url
        self.apiKey = apiKey
    }
    
    var auth: AuthClient { AuthClient(url: url, headerOptions: .init()) }
}