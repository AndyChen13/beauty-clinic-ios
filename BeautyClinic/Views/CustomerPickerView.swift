// Views/CustomerPickerView.swift
import SwiftUI

enum CustomerPickerMode: Identifiable {
    case recordTransaction
    case recordDelivery
    
    var id: CustomerPickerMode { self }
}

struct CustomerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let customers: [Customer]
    let mode: CustomerPickerMode
    let stores: [Store]
    let packages: [ServicePackage]
    let onSelect: (Customer) -> Void
    let onComplete: () -> Void
    
    @State private var searchTerm = ""
    @State private var selectedCustomerForTransaction: Customer?
    
    var filteredCustomers: [Customer] {
        if searchTerm.isEmpty { return customers }
        let term = searchTerm.lowercased()
        return customers.filter {
            $0.name.lowercased().contains(term) || $0.phone.contains(term)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCustomers) { customer in
                    Button {
                        if mode == .recordTransaction {
                            selectedCustomerForTransaction = customer
                        } else {
                            dismiss()
                            onSelect(customer)
                            onComplete()
                        }
                    } label: {
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
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if filteredCustomers.isEmpty {
                    ContentUnavailableView {
                        Label("暂无客户", systemImage: "person.2")
                    } description: {
                        Text("当前没有可选择的客户，请先返回首页添加或刷新客户列表。")
                    }
                }
            }
            .searchable(
                text: $searchTerm,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索客户姓名或手机号"
            )
            .navigationTitle(mode == .recordTransaction ? "选择客户（记录成交）" : "选择客户（记录交付）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedCustomerForTransaction) { customer in
                CustomerEditView(
                    mode: .edit(customer, openAddDeal: true),
                    stores: stores,
                    onSave: { _ in
                        selectedCustomerForTransaction = nil
                        dismiss()
                        onComplete()
                    }
                )
            }
        }
    }
}
