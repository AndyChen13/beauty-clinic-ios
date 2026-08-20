// Views/CustomerListView.swift
import SwiftUI

struct CustomerListView: View {
    @EnvironmentObject var userState: UserState
    @State private var customers: [Customer] = []
    @State private var stores: [Store] = []
    @State private var isLoading = false
    @State private var searchTerm = ""
    @State private var showingAddSheet = false
    @State private var showingDeleteRequest = false
    @State private var customerToDelete: Customer?
    @State private var deleteReason = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var filteredCustomers: [Customer] {
        if searchTerm.isEmpty { return customers }
        let term = searchTerm.lowercased()
        return customers.filter {
            $0.name.lowercased().contains(term) || $0.phone.contains(term)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchTerm, placeholder: "搜索客户...")
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
                            NavigationLink(destination: CustomerDetailView(customer: customer, stores: stores)) {
                                CustomerRow(customer: customer)
                            }
                            .swipeActions(edge: .trailing) {
                                if userState.isAdmin {
                                    Button(role: .destructive) {
                                        deleteCustomer(customer)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        customerToDelete = customer
                                        showingDeleteRequest = true
                                    } label: {
                                        Label("申请删除", systemImage: "trash")
                                    }
                                    .tint(.orange)
                                }
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
                CustomerEditView(mode: .create, stores: stores) { newCustomer in
                    customers.insert(newCustomer, at: 0)
                }
            }
            .sheet(isPresented: $showingDeleteRequest) {
                DeleteRequestSheet(
                    itemName: customerToDelete?.name ?? "",
                    reason: $deleteReason,
                    onSubmit: submitDeleteRequest
                )
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }
    
    private func deleteCustomer(_ customer: Customer) {
        guard userState.isAdmin else { return }
        Task {
            do {
                _ = try await supabase
                    .from("customers")
                    .delete()
                    .eq("id", value: customer.id)
                    .execute()
                await MainActor.run {
                    customers.removeAll { $0.id == customer.id }
                }
            } catch {
                errorMessage = "删除失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func submitDeleteRequest() {
        guard let customer = customerToDelete else { return }
        Task {
            do {
                let request = DeletionRequestInsert(
                    requesterId: userState.currentUser?.id ?? UUID(),
                    targetType: "customer",
                    targetId: customer.id,
                    targetName: customer.name,
                    reason: deleteReason.isEmpty ? nil : deleteReason
                )
                _ = try await supabase
                    .from("deletion_requests")
                    .insert(request)
                    .execute()
                await MainActor.run {
                    deleteReason = ""
                    customerToDelete = nil
                }
            } catch {
                errorMessage = "提交失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let customersTask: [Customer] = supabase
                .from("customers")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            async let storesTask: [Store] = supabase
                .from("stores")
                .select()
                .execute()
                .value
            
            let (c, s) = try await (customersTask, storesTask)
            customers = c
            stores = s
        } catch {
            print("Error loading data: \(error)")
        }
    }
}

struct CustomerRow: View {
    let customer: Customer
    
    var body: some View {
        HStack(spacing: 12) {
            if let photoUrl = customer.photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AvatarView(name: customer.name, size: 44)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                AvatarView(name: customer.name, size: 44)
            }
            
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

#Preview {
    CustomerListView()
        .environmentObject(UserState())
}
