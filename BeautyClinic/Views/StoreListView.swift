// Views/StoreListView.swift
import SwiftUI

struct StoreListView: View {
    @EnvironmentObject var userState: UserState
    @State private var stores: [Store] = []
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && stores.isEmpty {
                    List {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 80)
                                .shimmering()
                        }
                    }
                    .listStyle(.plain)
                } else if stores.isEmpty {
                    EmptyStateView(
                        icon: "building.2",
                        title: "暂无门店",
                        subtitle: "点击右上角添加门店"
                    )
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(stores) { store in
                            StoreRow(store: store, users: users)
                        }
                        .onDelete(perform: deleteStore)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("门店管理")
            .toolbar {
                if userState.isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                StoreEditView(mode: .create, users: users) { newStore in
                    stores.append(newStore)
                }
            }
            .task { await loadData() }
            .refreshable { await loadData() }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let storesTask: [Store] = supabase
                .from("stores")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            async let usersTask: [User] = supabase
                .from("users")
                .select()
                .execute()
                .value
            
            let (s, u) = try await (storesTask, usersTask)
            stores = s
            users = u
        } catch {
            print("Error loading stores: \(error)")
        }
    }
    
    private func deleteStore(at offsets: IndexSet) {
        guard userState.isAdmin, let index = offsets.first else { return }
        let store = stores[index]
        
        Task {
            do {
                _ = try await supabase
                    .from("stores")
                    .delete()
                    .eq("id", value: store.id)
                    .execute()
                
                await MainActor.run {
                    stores.remove(at: index)
                }
            } catch {
                errorMessage = "删除失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct StoreRow: View {
    let store: Store
    let users: [User]
    
    private var managerName: String {
        if let managerId = store.managerId,
           let user = users.first(where: { $0.id == managerId }) {
            return user.name
        }
        return "未指定"
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(store.status.color.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(store.status.color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.subheadline.weight(.medium))
                
                if let address = store.address, !address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(address)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.status.color)
                        .frame(width: 6, height: 6)
                    Text(store.status.displayName)
                        .font(.caption2)
                        .foregroundStyle(store.status.color)
                    
                    Text("负责人: \(managerName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

enum StoreEditMode {
    case create
    case edit(Store)
}

struct StoreEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: StoreEditMode
    let users: [User]
    let onSave: (Store) -> Void
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var status = StoreStatus.active
    @State private var managerId: UUID?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("门店名称 *", text: $name)
                    TextField("地址", text: $address, axis: .vertical)
                        .lineLimit(2...3)
                    TextField("联系电话", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("负责人") {
                    if users.isEmpty {
                        Text("暂无可选负责人")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("选择负责人", selection: $managerId) {
                            Text("不指定").tag(nil as UUID?)
                            ForEach(users) { user in
                                Text(user.name).tag(user.id as UUID?)
                            }
                        }
                    }
                }
                
                Section("状态") {
                    Picker("运营状态", selection: $status) {
                        ForEach(StoreStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("添加门店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveStore) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveStore() {
        guard !name.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                let storeData = StoreInsert(
                    name: name,
                    address: address.isEmpty ? nil : address,
                    phone: phone.isEmpty ? nil : phone,
                    status: status,
                    managerId: managerId
                )
                
                let created: [Store] = try await supabase
                    .from("stores")
                    .insert(storeData)
                    .select()
                    .execute()
                    .value
                
                onSave(created.first!)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    StoreListView()
        .environmentObject(UserState())
}
