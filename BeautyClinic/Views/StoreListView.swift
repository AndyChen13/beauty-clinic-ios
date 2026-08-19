//  Views/StoreListView.swift
//  BeautyClinic
//

import SwiftUI

struct StoreListView: View {
    @State private var stores: [Store] = []
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
                                .frame(height: 72)
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
                            StoreRow(store: store)
                        }
                        .onDelete(perform: deleteStore)
                    }
                    .listStyle(.plain)
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
                StoreEditView(mode: .create) { newStore in
                    stores.append(newStore)
                }
            }
            .task { await loadStores() }
            .refreshable { await loadStores() }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadStores() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: [Store] = try await supabase
                .from("stores")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            stores = result
        } catch {
            print("Error loading stores: \(error)")
        }
    }
    
    private func deleteStore(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let store = stores[index]
        
        Task {
            do {
                _ = try await supabase
                    .from("stores")
                    .delete()
                    .eq("id", value: store.id)
                    .execute()
                
                _ = await MainActor.run {
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
    let onSave: (Store) -> Void
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var status = StoreStatus.active
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
                    managerUserId: nil
                )
                
                let created: Store = try await supabase
                    .from("stores")
                    .insert(storeData)
                    .select()
                    .single()
                    .execute()
                    .value
                
                onSave(created)
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
}
