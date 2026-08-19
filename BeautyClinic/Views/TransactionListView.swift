// TransactionListView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct TransactionListView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var showingRecordSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                FilterBar()
                
                List {
                    ForEach(transactions, id: \.id) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture {
                                // Navigate to transaction detail
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("成交记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRecordSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingRecordSheet) {
                TransactionRecordView()
            }
            .onAppear { loadTransactions() }
        }
    }
    
    private func loadTransactions() {
        isLoading = true
        Task {
            do {
                let data = try await supabaseClient?.from("transactions")
                    .select()
                    .order("transaction_date", ascending: false)
                transactions = data?.compactMap { Transaction(json: $0) } ?? []
            } catch {
                print("Error loading transactions: \(error)")
            }
            isLoading = false
        }
    }
}

#Preview {
    TransactionListView()
}