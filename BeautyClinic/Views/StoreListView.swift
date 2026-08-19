// StoreListView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct StoreListView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var stores: [Store] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(stores, id: \.id) { store in
                    StoreRow(store: store)
                        .onTapGesture {
                            // Navigate to store detail or edit
                        }
                        .swipeActions(edge: .trailing) {
                            Button("编辑") {
                                // TODO: Edit store
                            }
                            Button(role: .destructive) {
                                // TODO: Delete store
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                }
            }
            .navigationTitle("门店管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                StoreEditView(store: nil)
            }
            .onAppear { loadStores() }
        }
    }
    
    private func loadStores() {
        isLoading = true
        Task {
            do {
                let data = try await supabaseClient?.from("stores").select()
                stores = data?.compactMap { Store(json: $0) } ?? []
            } catch {
                print("Error loading stores: \(error)")
            }
            isLoading = false
        }
    }
}

#Preview {
    StoreListView()
}