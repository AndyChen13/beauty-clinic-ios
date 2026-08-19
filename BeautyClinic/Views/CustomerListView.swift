//  Views/CustomerListView.swift
//  BeautyClinic
//

import SwiftUI

struct CustomerListView: View {
    @State private var customers: [Customer] = []
    @State private var isLoading = false
    @State private var searchTerm = ""
    @State private var showingAddSheet = false
    @State private var errorMessage: String?
    
    var filteredCustomers: [Customer] {
        if searchTerm.isEmpty { return customers }
        let term = searchTerm.lowercased()
        return customers.filter {
            $0.name.lowercased().contains(term) ||
            $0.phone.contains(term)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchTerm)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                if isLoading && customers.isEmpty {
                    List {
                        ForEach(0..<6) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 56)
                                .shimmering()
                        }
                    }
                    .listStyle(.plain)
                } else if filteredCustomers.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: searchTerm.isEmpty ? "暂无客户" : "未找到匹配客户",
                        subtitle: searchTerm.isEmpty ? "点击右上角添加第一位客户" : "尝试其他关键词"
                    )
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(filteredCustomers) { customer in
                            NavigationLink(destination: CustomerDetailView(customer: customer)) {
                                CustomerRow(customer: customer)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
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
                CustomerEditView(mode: .create) { newCustomer in
                    customers.insert(newCustomer, at: 0)
                }
            }
            .task { await loadCustomers() }
            .refreshable { await loadCustomers() }
        }
    }
    
    private func loadCustomers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: [Customer] = try await supabase
                .from("customers")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            customers = result
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("Error loading customers: \(error)")
        }
    }
}

struct CustomerRow: View {
    let customer: Customer
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: customer.name, size: 44)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(customer.name)
                    .font(.subheadline.weight(.medium))
                Text(customer.phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let age = customer.age {
                Text("\(age)岁")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40
    
    private var initial: String {
        let first = name.prefix(1)
        return String(first)
    }
    
    private var bgColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        let hash = name.utf8.reduce(0) { $0 + Int($1) }
        return colors[hash % colors.count]
    }
    
    var body: some View {
        Circle()
            .fill(bgColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(bgColor)
            )
    }
}

#Preview {
    CustomerListView()
}
