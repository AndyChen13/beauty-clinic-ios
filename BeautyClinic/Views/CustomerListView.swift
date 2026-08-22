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
    
    // Two-step delete confirmation
    @State private var showDeliveryCheck = false
    @State private var showFinalDeleteConfirm = false
    @State private var pendingDeliveryCount = 0
    @State private var deleteTargetCustomer: Customer?
    
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
                                        startDeleteCustomer(customer)
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
            // Step 1: Delivery check
            .alert("交付确认", isPresented: $showDeliveryCheck) {
                Button("交付完成", role: .none) {
                    showFinalDeleteConfirm = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("该客户还有 \(pendingDeliveryCount) 次待交付。\n\n请确认该客户已交付完成。")
            }
            // Step 2: Final delete confirmation
            .alert("确认删除", isPresented: $showFinalDeleteConfirm) {
                Button("删除", role: .destructive) {
                    if let customer = deleteTargetCustomer {
                        performDelete(customer)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请确认删除客户「\(deleteTargetCustomer?.name ?? "")」。此操作不可撤销。")
            }
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }
    
    private func startDeleteCustomer(_ customer: Customer) {
        guard userState.isAdmin else { return }
        deleteTargetCustomer = customer
        
        Task {
            do {
                let records: [ServiceRecord] = try await supabase
                    .from("service_records")
                    .select()
                    .eq("customer_id", value: customer.id)
                    .execute()
                    .value
                
                let pendingCount = records.reduce(0) { $0 + ($1.remainingSessions ?? 0) }
                
                await MainActor.run {
                    pendingDeliveryCount = pendingCount
                    if pendingCount > 0 {
                        showDeliveryCheck = true
                    } else {
                        showFinalDeleteConfirm = true
                    }
                }
            } catch {
                await MainActor.run {
                    showFinalDeleteConfirm = true
                }
            }
        }
    }
    
    private func performDelete(_ customer: Customer) {
        Task {
            do {
                // 1. 先删除关联的服务记录
                _ = try await supabase
                    .from("service_records")
                    .delete()
                    .eq("customer_id", value: customer.id)
                    .execute()
                
                // 2. 删除关联的照片记录
                _ = try await supabase
                    .from("customer_photos")
                    .delete()
                    .eq("customer_id", value: customer.id)
                    .execute()
                
                // 3. 最后删除客户
                _ = try await supabase
                    .from("customers")
                    .delete()
                    .eq("id", value: customer.id)
                    .execute()
                
                await MainActor.run {
                    customers.removeAll { $0.id == customer.id }
                    deleteTargetCustomer = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                    showError = true
                }
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
