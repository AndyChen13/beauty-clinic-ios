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
    
    @State private var showDeliveryCheck = false
    @State private var showFinalDeleteConfirm = false
    @State private var pendingDeliveryCount = 0
    @State private var deleteTargetCustomer: Customer?
    @State private var selectedTagFilter: TagFilter = .all
    @State private var selectedStoreId: UUID?
    
    enum TagFilter: CaseIterable {
        case all, photoElectric, medicalBeauty, both
        
        var title: String {
            switch self {
            case .all: return "全部"
            case .photoElectric: return "光 · 电"
            case .medicalBeauty: return "医 · 美"
            case .both: return "光+医"
            }
        }
    }
    
    var filteredCustomers: [Customer] {
        var result = customers
        switch selectedTagFilter {
        case .all:
            break
        case .photoElectric:
            result = result.filter { $0.branchTags.contains(.photoElectric) }
        case .medicalBeauty:
            result = result.filter { $0.branchTags.contains(.medicalBeauty) }
        case .both:
            result = result.filter {
                $0.branchTags.contains(.photoElectric) && $0.branchTags.contains(.medicalBeauty)
            }
        }
        if let storeId = selectedStoreId {
            result = result.filter { $0.associatedStoreId == storeId }
        }
        if searchTerm.isEmpty { return result }
        let term = searchTerm.lowercased()
        return result.filter {
            $0.name.lowercased().contains(term) || $0.phone.contains(term)
        }
    }
    
    private var selectedStoreName: String {
        if let storeId = selectedStoreId,
           let store = stores.first(where: { $0.id == storeId }) {
            return store.name
        }
        return "全部门店"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchTerm, placeholder: "搜索客户...")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TagFilter.allCases, id: \.self) { filter in
                            CustomerTagChip(
                                title: filter.title,
                                isSelected: selectedTagFilter == filter,
                                color: .primary
                            ) {
                                selectedTagFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 6)
                
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
                            let storeName = stores.first(where: { $0.id == customer.associatedStoreId })?.name
                            NavigationLink(destination: CustomerDetailView(customer: customer, stores: stores)) {
                                CustomerRow(customer: customer, storeName: storeName)
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
                    Menu {
                        Button("全部门店") { selectedStoreId = nil }
                        Divider()
                        ForEach(stores) { store in
                            Button(store.name) { selectedStoreId = store.id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedStoreName)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                }
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
                    onSubmit: submitDeleteApproval
                )
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("交付确认", isPresented: $showDeliveryCheck) {
                Button("交付完成", role: .none) {
                    showFinalDeleteConfirm = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("该客户还有 \(pendingDeliveryCount) 次待交付。\n\n请确认该客户已交付完成。")
            }
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
            .onAppear { Task { await loadData() } }
        }
    }
    
    private func startDeleteCustomer(_ customer: Customer) {
        guard userState.isAdmin else { return }
        deleteTargetCustomer = customer
        
        if let remaining = customer.remainingSessions, remaining > 0 {
            pendingDeliveryCount = remaining
            showDeliveryCheck = true
        } else {
            showFinalDeleteConfirm = true
        }
    }
    
    private func performDelete(_ customer: Customer) {
        Task {
            do {
                try await CustomerService.shared.deleteCustomer(id: customer.id)
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
    
    private func submitDeleteApproval() {
        guard let customer = customerToDelete else { return }
        Task {
            do {
                var payload: [String: JSONValue] = [:]
                payload["customerName"] = .string(customer.name)
                if !deleteReason.isEmpty {
                    payload["reason"] = .string(deleteReason)
                }
                _ = try await AdminService.shared.createOperationApproval(
                    operationType: "delete",
                    targetType: "customer",
                    targetId: customer.id,
                    payload: payload
                )
                await MainActor.run {
                    deleteReason = ""
                    customerToDelete = nil
                    showingDeleteRequest = false
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
            async let customersTask = CustomerService.shared.listCustomers()
            async let storesTask = StoreService.shared.listStores()
            
            let (c, s) = try await (customersTask, storesTask)
            customers = c
            stores = s
        } catch {
            print("Error loading data: \(error)")
        }
    }
}

struct CustomerTagChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                .foregroundStyle(isSelected ? color : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CustomerRow: View {
    let customer: Customer
    let storeName: String?
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
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
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(customer.name)
                        .font(.subheadline.weight(.medium))
                    ForEach(customer.branchTags, id: \.self) { tag in
                        Text(tag.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(tag.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(customer.phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    if let storeName = storeName, !storeName.isEmpty {
                        Label {
                            Text(storeName)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "storefront")
                                .font(.caption2)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Capsule())
                    }
                    
                    Spacer(minLength: 6)
                    
                    if let createdAt = customer.createdAt {
                        Label {
                            Text(Self.dateFormatter.string(from: createdAt))
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption2)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
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
