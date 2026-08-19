// Views/TransactionListView.swift
import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var userState: UserState
    @State private var transactions: [Transaction] = []
    @State private var deliveries: [Delivery] = []
    @State private var customers: [Customer] = []
    @State private var packages: [ServicePackage] = []
    @State private var isLoading = false
    @State private var showingRecordSheet = false
    @State private var selectedStatus: TransactionStatus? = nil
    @State private var selectedTransaction: Transaction? = nil
    @State private var showingDeliverySheet = false
    
    var filteredTransactions: [Transaction] {
        guard let status = selectedStatus else { return transactions }
        return transactions.filter { $0.status == status }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        StatusFilterChip(
                            title: "全部",
                            isSelected: selectedStatus == nil
                        ) { selectedStatus = nil }
                        
                        ForEach(TransactionStatus.allCases, id: \.self) { status in
                            StatusFilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                color: status.color
                            ) { selectedStatus = status }
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
                                .frame(height: 120)
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
                            TransactionRow(transaction: transaction, deliveries: deliveriesFor(transaction))
                                .onTapGesture {
                                    selectedTransaction = transaction
                                    showingDeliverySheet = true
                                }
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
                TransactionRecordView(
                    customers: customers,
                    packages: packages
                ) { newTransaction in
                    transactions.insert(newTransaction, at: 0)
                }
            }
            .sheet(isPresented: $showingDeliverySheet) {
                if let transaction = selectedTransaction {
                    DeliveryRecordView(
                        transaction: transaction,
                        existingDeliveries: deliveriesFor(transaction)
                    ) { _ in
                        Task { await loadData() }
                    }
                }
            }
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }
    
    private func deliveriesFor(_ transaction: Transaction) -> [Delivery] {
        deliveries.filter { $0.transactionId == transaction.id }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let transactionsTask: [Transaction] = supabase
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
            
            async let deliveriesTask: [Delivery] = supabase
                .from("deliveries")
                .select()
                .order("delivery_date", ascending: false)
                .execute()
                .value
            
            async let customersTask: [Customer] = supabase
                .from("customers")
                .select()
                .execute()
                .value
            
            async let packagesTask: [ServicePackage] = supabase
                .from("packages")
                .select()
                .execute()
                .value
            
            let (t, d, c, p) = try await (transactionsTask, deliveriesTask, customersTask, packagesTask)
            transactions = t
            deliveries = d
            customers = c
            packages = p
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
    let deliveries: [Delivery]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
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
            
            // Progress bar
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.tertiarySystemBackground))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(transaction.status.color)
                            .frame(width: geo.size.width * transaction.progressPercentage, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text("\(transaction.completedSessions)/\(transaction.totalSessions)次")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
            }
            
            if let estDate = transaction.estimatedCompletionDate {
                Text("预计完成: \(formatDate(estDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !deliveries.isEmpty {
                Text("已交付 \(deliveries.count) 次")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

struct TransactionRecordView: View {
    @Environment(\.dismiss) private var dismiss
    
    let customers: [Customer]
    let packages: [ServicePackage]
    let onSave: (Transaction) -> Void
    
    @State private var selectedCustomerId: UUID?
    @State private var selectedPackageId: UUID?
    @State private var amount = ""
    @State private var totalSessions = "1"
    @State private var notes = ""
    @State private var selectedDate = Date()
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("客户信息") {
                    if customers.isEmpty {
                        Text("暂无客户")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("选择客户", selection: $selectedCustomerId) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(customers) { customer in
                                Text(customer.name).tag(customer.id as UUID?)
                            }
                        }
                    }
                }
                
                Section("套餐信息") {
                    if packages.isEmpty {
                        Text("暂无套餐")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("选择套餐", selection: $selectedPackageId) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(packages.filter { $0.isActive }) { package in
                                Text("\(package.name) (¥\(Int(package.price)))").tag(package.id as UUID?)
                            }
                        }
                    }
                }
                
                Section("成交信息") {
                    TextField("金额 (¥) *", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("总次数", text: $totalSessions)
                        .keyboardType(.numberPad)
                    DatePicker("成交时间", selection: $selectedDate)
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
                    .disabled(selectedCustomerId == nil || selectedPackageId == nil || amount.isEmpty || isSaving)
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
        guard let customerId = selectedCustomerId,
              let packageId = selectedPackageId,
              let amountValue = Double(amount),
              let sessions = Int(totalSessions) else { return }
        
        isSaving = true
        
        Task {
            do {
                // Get customer to find store
                let customer = customers.first { $0.id == customerId }
                guard let storeId = customer?.associatedStoreId else {
                    errorMessage = "该客户未关联门店，请先为客户分配门店"
                    showError = true
                    isSaving = false
                    return
                }
                
                // Calculate estimated completion date
                let calendar = Calendar.current
                let estDate = calendar.date(byAdding: .day, value: sessions * 7, to: selectedDate)
                
                let transactionData = TransactionInsert(
                    customerId: customerId,
                    storeId: storeId,
                    packageId: packageId,
                    staffUserId: nil,
                    amount: amountValue,
                    totalSessions: sessions,
                    transactionDate: selectedDate,
                    estimatedCompletionDate: estDate,
                    status: .confirmed,
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

struct DeliveryRecordView: View {
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    let existingDeliveries: [Delivery]
    let onSave: (Delivery) -> Void
    
    @State private var notes = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("成交信息") {
                    InfoRow(label: "客户", value: transaction.customerName ?? "未知")
                    InfoRow(label: "套餐", value: transaction.packageName ?? "未知")
                    InfoRow(label: "总金额", value: "¥\(String(format: "%.0f", transaction.amount))")
                    InfoRow(label: "进度", value: "\(transaction.completedSessions)/\(transaction.totalSessions)次")
                }
                
                Section("交付记录") {
                    if existingDeliveries.isEmpty {
                        Text("暂无交付记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(existingDeliveries) { delivery in
                            HStack {
                                Text("第\(delivery.sessionNumber)次交付")
                                    .font(.subheadline)
                                Spacer()
                                Text(delivery.deliveryDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                if transaction.completedSessions < transaction.totalSessions {
                    Section("新增交付") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                    }
                } else {
                    Section {
                        Text("已全部交付完成")
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("交付管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if transaction.completedSessions < transaction.totalSessions {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: recordDelivery) {
                            if isSaving {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("记录交付")
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
    }
    
    private func recordDelivery() {
        isSaving = true
        
        Task {
            do {
                let nextSession = transaction.completedSessions + 1
                
                let deliveryData = DeliveryInsert(
                    transactionId: transaction.id,
                    customerId: transaction.customerId,
                    storeId: transaction.storeId,
                    staffUserId: nil,
                    sessionNumber: nextSession,
                    notes: notes.isEmpty ? nil : notes,
                    photos: nil
                )
                
                let created: Delivery = try await supabase
                    .from("deliveries")
                    .insert(deliveryData)
                    .select()
                    .single()
                    .execute()
                    .value
                
                // Update transaction
                _ = try await supabase
                    .from("transactions")
                    .update([
                        "completed_sessions": String(nextSession),
                        "first_delivery_date": existingDeliveries.isEmpty ? ISO8601DateFormatter().string(from: Date()) : nil,
                        "status": nextSession >= transaction.totalSessions ? "completed" : "in_progress"
                    ])
                    .eq("id", value: transaction.id)
                    .execute()
                
                onSave(created)
                dismiss()
            } catch {
                print("Error recording delivery: \(error)")
            }
            isSaving = false
        }
    }
}

#Preview {
    TransactionListView()
        .environmentObject(UserState())
}
