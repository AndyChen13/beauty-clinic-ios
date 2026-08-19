// CustomerListView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct CustomerListView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var customers: [Customer] = []
    @State private var isLoading = false
    @State private var searchTerm = ""
    @State private var showingAddSheet = false
    
    var filteredCustomers: [Customer] {
        if searchTerm.isEmpty { return customers }
        return customers.filter { $0.name.contains(searchTerm) || $0.phone.contains(searchTerm) }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchTerm)
                    .padding(.horizontal)
                
                List {
                    ForEach(filteredCustomers, id: \.id) { customer in
                        NavigationLink(destination: CustomerDetailView(customer: customer)) {
                            CustomerRow(customer: customer)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("客户管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CustomerEditView(customer: nil)
            }
            .onAppear { loadCustomers() }
        }
    }
    
    private func loadCustomers() {
        isLoading = true
        Task {
            do {
                let data = try await supabaseClient?.from("customers").select()
                customers = data?.compactMap { Customer(json: $0) } ?? []
            } catch {
                print("Error loading customers: \(error)")
            }
            isLoading = false
        }
    }
}

#Preview {
    CustomerListView()
}