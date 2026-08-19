//  Views/TransactionListView.swift
//  BeautyClinic
//

import SwiftUI

struct TransactionListView: View {
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var showingRecordSheet = false
    @State private var selectedStatus: TransactionStatus? = nil
    
    var filteredTransactions: [Transaction] {
        guard let status = selectedStatus else { return transactions }
        return transactions.filter { $0.status == status }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        StatusFilterChip(
                            title: "全部",
                            isSelected: selectedStatus == nil
                        ) {
                            selectedStatus = nil
                        }
                        
                        ForEach(TransactionStatus.allCases, id: \.self) { status in
                            StatusFilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                color: status.color
                            ) {
                                selectedStatus = status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                if isLoading && transactions.isEmpty {
                    List {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 90)
                                .shimmering()
                        }
                    }
                    .listStyle(.plain)
                } else if filteredTransactions.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: selectedStatus == nil ? "暂无成交记录" : "该状态暂无记录",
                        subtitle: "点击右上角记录第一笔成交"
                    )
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(filteredTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                    .listStyle(.plain)
                }
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
                TransactionRecordView { newTransaction in
                    transactions.insert(newTransaction, at: 0)
                }
            }
            .task { await loadTransactions() }
            .refreshable { await loadTransactions() }
        }
    }
    
    private func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: [Transaction] = try await supabase
                .from("transactions")
                .select("""
                    *,
                    customers(name),
                    packages(name),
                    stores(name)
                """)
                .order("transaction_date", ascending: false)
                .execute()
                .value
            transactions = result
        } catch {
            print("Error loading transactions: \(error)")
        }
    }
}

struct StatusFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .accentColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? color : .primary)
                .clipShape(Capsule())
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Circle()
                    .fill(transaction.status.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(transaction.status.color)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.packageName ?? "未知套餐")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 6) {
                        Text(transaction.status.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(transaction.status.color.opacity(0.12))
                            .foregroundColor(transaction.status.color)
                            .clipShape(Capsule())
                        Text(formatDate(transaction.transactionDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text("¥\(String(format: "%.0f", transaction.amount))")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
            
            HStack(spacing: 12) {
                Label(transaction.customerName ?? "未知客户", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(transaction.storeName ?? "未知门店", systemImage: "building.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let notes = transaction.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct TransactionRecordView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (Transaction) -> Void
    
    @State private var customerName = ""
    @State private var packageName = ""
    @State private var amount = ""
    @State private var notes = ""
    @State private var selectedDate = Date()
    @State private var status = TransactionStatus.pending
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("客户信息") {
                    TextField("客户姓名 *", text: $customerName)
                }
                
                Section("服务信息") {
                    TextField("套餐名称 *", text: $packageName)
                    
                    TextField("金额 (¥) *", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("预约/成交时间", selection: $selectedDate)
                    
                    Picker("状态", selection: $status) {
                        ForEach(TransactionStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("记录成交")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveTransaction) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(customerName.isEmpty || packageName.isEmpty || amount.isEmpty || isSaving)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount),
              !customerName.isEmpty,
              !packageName.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                // Note: In a real app, you'd look up the actual customer_id and package_id
                // For now, we'll create with placeholder IDs that will need proper handling
                let transactionData = TransactionInsert(
                    customerId: UUID(),
                    storeId: UUID(),
                    packageId: UUID(),
                    staffUserId: nil,
                    amount: amountValue,
                    transactionDate: selectedDate,
                    scheduledAt: nil,
                    status: status,
                    notes: notes.isEmpty ? nil : notes
                )
                
                let created: Transaction = try await supabase
                    .from("transactions")
                    .insert(transactionData)
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
    TransactionListView()
}
