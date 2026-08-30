// Views/CustomerDetailView.swift
import SwiftUI

struct CustomerDetailView: View {
    @EnvironmentObject var userState: UserState
    @State var customer: Customer
    let stores: [Store]
    @State private var transactions: [Transaction] = []
    
    init(customer: Customer, stores: [Store]) {
        _customer = State(initialValue: customer)
        self.stores = stores
    }
    @State private var serviceRecords: [ServiceRecord] = []
    @State private var isLoading = false
    @State private var isEditing = false
    @State private var showingServiceSheet = false
    @State private var showingRefundSheet = false
    @State private var showingPaymentSheet = false
    @State private var selectedTransactionForPayment: Transaction?
    @State private var selectedRecord: ServiceRecord?
    
    private var storeName: String {
        if let storeId = customer.associatedStoreId,
           let store = stores.first(where: { $0.id == storeId }) {
            return store.name
        }
        return "未分配门店"
    }
    
    // MARK: - 成交统计（按交易记录实时聚合，额外收款不重复计算）
    private var nonPaymentTransactions: [Transaction] {
        transactions.filter { $0.status != .paid }
    }
    
    private var paymentTransactions: [Transaction] {
        transactions.filter { $0.status == .paid }
    }
    
    private var statsTotalAmount: Double {
        // 成交金额 = 所有成交/退款 amount 之和 + 后续额外收款/服务记录收款（status=paid）的 amountReceived
        let dealTotal = nonPaymentTransactions.reduce(0) { $0 + $1.amount }
        let extraPayments = paymentTransactions.reduce(0) { $0 + ($1.amountReceived ?? 0) }
        let total = dealTotal + extraPayments
        return total > 0 ? total : (customer.firstTransactionAmount ?? 0)
    }
    
    private var statsReceived: Double {
        // 已收款 = 成交记录收款 + 服务记录额外收款（paid 且 amount≠0） + 退款（负值）
        let dealReceived = nonPaymentTransactions.reduce(0) { $0 + ($1.amountReceived ?? 0) }
        let extraPayments = paymentTransactions
            .filter { $0.amount != 0 }
            .reduce(0) { $0 + ($1.amountReceived ?? 0) }
        let refundReceived = transactions
            .filter { $0.status == .refunded }
            .reduce(0) { $0 + ($1.amountReceived ?? 0) }
        let total = dealReceived + extraPayments + refundReceived
        return transactions.isEmpty ? (customer.amountReceived ?? 0) : total
    }
    
    private var statsOutstanding: Double {
        // 待收款从非 paid 成交聚合
        nonPaymentTransactions.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    
    private var statsTotalSessions: Int {
        let txTotal = nonPaymentTransactions.reduce(0) { $0 + $1.totalSessions }
        return txTotal > 0 ? txTotal : (customer.remainingSessions ?? 0)
    }
    
    private var statsRemaining: Int {
        let txRemaining = nonPaymentTransactions.reduce(0) { $0 + $1.remainingSessions }
        return txRemaining > 0 ? txRemaining : (customer.remainingSessions ?? 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileCard
                infoCard
                
                if let history = customer.medicalHistory, !history.isEmpty {
                    medicalHistoryCard(history: history)
                }
                
                if let prefs = customer.preferences, !prefs.isEmpty {
                    preferencesCard(prefs: prefs)
                }
                
                customerStatsCard
                serviceRecordsSection
                transactionsSection
            }
            .padding()
        }
        .navigationTitle(customer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingServiceSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    Button("编辑") { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            CustomerEditView(mode: .edit(customer), stores: stores) { updated in
                customer = updated
                Task {
                    await loadTransactions()
                    await loadCustomer()
                    await loadServiceRecords()
                }
            }
        }
        .sheet(isPresented: $showingServiceSheet) {
            ServiceRecordEditView(
                record: nil,
                customer: customer,
                transactions: transactions
            ) { _ in
                Task {
                    await loadServiceRecords()
                    await loadTransactions()
                    await loadCustomer()
                }
            }
        }
        .sheet(isPresented: $showingRefundSheet) {
            AddRefundSheet(
                customer: customer,
                transactions: transactions,
                onSave: {
                    Task {
                        await loadTransactions()
                        await loadCustomer()
                    }
                },
                onCancel: { showingRefundSheet = false }
            )
        }
        .sheet(item: $selectedTransactionForPayment) { transaction in
            AddPaymentSheet(
                customer: customer,
                transactions: transactions,
                transaction: transaction,
                onSave: {
                    Task {
                        await loadTransactions()
                        await loadCustomer()
                    }
                },
                onCancel: { selectedTransactionForPayment = nil }
            )
        }
        .sheet(isPresented: $showingPaymentSheet) {
            AddPaymentSheet(
                customer: customer,
                transactions: transactions,
                transaction: nil,
                onSave: {
                    Task {
                        await loadTransactions()
                        await loadCustomer()
                    }
                },
                onCancel: { showingPaymentSheet = false }
            )
        }
        .task {
            await loadTransactions()
            await loadServiceRecords()
        }
    }
    
    private var profileCard: some View {
        VStack(spacing: 14) {
            if let photoUrl = customer.photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AvatarView(name: customer.name, size: 72)
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
            } else {
                AvatarView(name: customer.name, size: 72)
            }
            
            HStack(spacing: 8) {
                Text(customer.name)
                    .font(.title2.weight(.bold))
                ForEach(customer.branchTags, id: \.self) { tag in
                    Text(tag.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tag.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tag.color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Text(customer.phone)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("归属: \(storeName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                InfoBadge(label: "性别", value: customer.genderDisplay)
                if let age = customer.age {
                    InfoBadge(label: "年龄", value: "\(age)岁")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
            
            InfoRow(label: "手机号", value: customer.phone)
            Divider()
            InfoRow(label: "性别", value: customer.genderDisplay)
            if let birthdate = customer.birthdate {
                Divider()
                InfoRow(label: "出生日期", value: birthdate)
            }
            if let firstTransactionDate = customer.firstTransactionDate {
                Divider()
                InfoRow(label: "首次成交", value: firstTransactionDate.formatted(date: .abbreviated, time: .omitted))
            }
            if let lastVisit = customer.lastVisit {
                Divider()
                InfoRow(label: "最近到访", value: lastVisit.formatted())
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func medicalHistoryCard(history: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("身体情况")
                .font(.headline)
            Text(history)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func preferencesCard(prefs: [String: String]) -> some View {
        let filtered = prefs.filter { $0.key != "branch" }
        return VStack(alignment: .leading, spacing: 12) {
            Text("客户偏好")
                .font(.headline)
            ForEach(Array(filtered.keys.sorted()), id: \.self) { key in
                if let value = filtered[key] {
                    InfoRow(label: key, value: value)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("成交历史")
                    .font(.headline)
                Spacer()
                Button("新增退款") {
                    showingRefundSheet = true
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.red)
                Button("新增收款") {
                    showingPaymentSheet = true
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.green)
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            if transactions.isEmpty && !isLoading {
                Text("暂无消费记录")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(transactions) { transaction in
                    TransactionMiniRow(transaction: transaction) {
                        selectedTransactionForPayment = transaction
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var customerStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("成交历史")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(statsRemaining)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(statsRemaining > 0 ? .blue : .gray)
                        Text("剩余次数")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(statsTotalSessions)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.blue)
                        Text("总服务次数")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if statsOutstanding > 0 {
                        VStack(spacing: 4) {
                            Text("¥\(String(format: "%.0f", statsOutstanding))")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.orange)
                            Text("待收款项")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if statsTotalAmount > 0 {
                        VStack(spacing: 4) {
                            Text("¥\(String(format: "%.0f", statsTotalAmount))")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.blue)
                            Text("成交金额")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if statsReceived > 0 {
                        VStack(spacing: 4) {
                            Text("¥\(String(format: "%.0f", statsReceived))")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.green)
                            Text("已收款")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !serviceRecords.isEmpty {
                        VStack(spacing: 4) {
                            Text("\(serviceRecords.count)")
                                .font(.title3.weight(.bold))
                            Text("服务次数")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var serviceRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("服务记录")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            if serviceRecords.isEmpty && !isLoading {
                Text("暂无服务记录")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(serviceRecords.prefix(5)) { record in
                    Button {
                        selectedRecord = record
                    } label: {
                        ServiceRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
                
                if serviceRecords.count > 5 {
                    Text("还有 \(serviceRecords.count - 5) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(item: $selectedRecord) { record in
            NavigationStack {
                ServiceRecordDetailView(
                    record: record,
                    customer: customer,
                    transactions: transactions,
                    onDelete: {
                        Task {
                            await loadCustomer()
                            await loadServiceRecords()
                        }
                    },
                    onSave: {
                        Task {
                            await loadCustomer()
                            await loadServiceRecords()
                            await loadTransactions()
                        }
                    }
                )
            }
        }
    }
    
    private func loadTransactions() async {
        do {
            transactions = try await TransactionService.shared.listTransactions(customerId: customer.id.uuidString)
        } catch {
            print("Error loading transactions: \(error)")
        }
    }
    
    private func loadCustomer() async {
        do {
            let updated = try await CustomerService.shared.getCustomer(id: customer.id)
            customer = updated
        } catch {
            print("Error loading customer: \(error)")
        }
    }
    
    private func loadServiceRecords() async {
        do {
            struct RecordResponse: Codable {
                let id: String
                let customerId: String
                let transactionId: String?
                let serviceDate: String
                let operatorId: String?
                let operatorName: String?
                let operatorPhone: String?
                let bodyPart: String?
                let serviceDetails: String?
                let photos: [String]?
                let customerFeedback: String?
                let extraPayment: Double
                let extraPaymentNote: String?
                let sessionsUsed: Int
                let remainingSessions: Int?
                let createdAt: String?
            }
            let result: [RecordResponse] = try await APIClient.shared.get(
                path: "/api/service-records?customerId=\(customer.id.uuidString)"
            )
            let formatter = ISO8601DateFormatter()
            serviceRecords = result.map { r in
                ServiceRecord(
                    id: UUID(uuidString: r.id)!,
                    customerId: UUID(uuidString: r.customerId)!,
                    transactionId: r.transactionId.flatMap { UUID(uuidString: $0) },
                    serviceDate: formatter.date(from: r.serviceDate) ?? Date(),
                    operatorId: r.operatorId.flatMap { UUID(uuidString: $0) },
                    operatorName: r.operatorName,
                    operatorPhone: r.operatorPhone,
                    bodyPart: r.bodyPart,
                    serviceDetails: r.serviceDetails,
                    photos: r.photos,
                    customerFeedback: r.customerFeedback,
                    extraPayment: r.extraPayment,
                    extraPaymentNote: r.extraPaymentNote,
                    sessionsUsed: r.sessionsUsed,
                    remainingSessions: r.remainingSessions,
                    createdAt: nil
                )
            }
        } catch {
            print("Error loading service records: \(error)")
        }
    }
}

struct AddRefundSheet: View {
    let customer: Customer
    let transactions: [Transaction]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var userState: UserState
    @State private var selectedTransactionId: UUID?
    @State private var refundAmount: String = ""
    @State private var refundSessions: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var selectedTransaction: Transaction? {
        transactions.first { $0.id == selectedTransactionId }
    }
    
    private var refundAmountValue: Double {
        Double(refundAmount) ?? 0
    }
    
    private var refundSessionsValue: Int {
        Int(refundSessions) ?? 0
    }
    
    private var canSave: Bool {
        (refundAmountValue > 0 || refundSessionsValue > 0) && selectedTransaction != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("选择退款对应成交") {
                    if transactions.isEmpty {
                        Text("没有可退款的成交记录")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("成交记录", selection: $selectedTransactionId) {
                            ForEach(transactions.filter { $0.status != .refunded && $0.status != .paid }) { tx in
                                Text("\(tx.packageName ?? "未知套餐") · ¥\(String(format: "%.0f", tx.amount)) · 剩余\(tx.remainingSessions)次")
                                    .tag(tx.id as UUID?)
                            }
                        }
                    }
                }
                
                Section("退款信息") {
                    TextField("退款金额 (¥)", text: $refundAmount)
                        .keyboardType(.decimalPad)
                    TextField("退还服务次数", text: $refundSessions)
                        .keyboardType(.numberPad)
                    TextField("退款备注（选填）", text: $notes)
                }
                
                Section {
                    Button {
                        saveRefund()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("确认退款")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSave || isSaving)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("新增退款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { onCancel() }
                }
            }
            .alert("退款失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if selectedTransactionId == nil {
                    selectedTransactionId = transactions.first { $0.status != .refunded && $0.status != .paid }?.id
                }
            }
        }
    }
    
    private func saveRefund() {
        guard refundAmountValue > 0 || refundSessionsValue > 0 else { return }
        guard let storeId = customer.associatedStoreId ?? userState.storeId else {
            errorMessage = "客户未分配门店"
            showError = true
            return
        }
        guard let targetTx = selectedTransaction else {
            errorMessage = "请选择要退款的成交记录"
            showError = true
            return
        }
        
        isSaving = true
        Task {
            do {
                let refund = TransactionInsert(
                    customerId: customer.id,
                    storeId: storeId,
                    packageId: targetTx.packageId,
                    staffUserId: userState.currentUser?.id,
                    amount: -refundAmountValue,
                    amountReceived: -refundAmountValue,
                    outstandingAmount: 0,
                    totalSessions: -refundSessionsValue,
                    transactionDate: Date(),
                    estimatedCompletionDate: nil,
                    status: .refunded,
                    notes: notes.isEmpty ? "退款 · \(targetTx.packageName ?? "")" : "退款 · \(targetTx.packageName ?? "")：\(notes)"
                )
                _ = try await TransactionService.shared.createTransaction(refund)
                
                // 同步刷新客户档案财务字段
                if let refreshed = try? await CustomerService.shared.getCustomer(id: customer.id) {
                    let update = CustomerInsert(
                        phone: refreshed.phone,
                        name: refreshed.name,
                        gender: refreshed.gender,
                        birthdate: refreshed.birthdate,
                        medicalHistory: refreshed.medicalHistory,
                        preferences: refreshed.preferences,
                        associatedStoreId: refreshed.associatedStoreId,
                        photoUrl: refreshed.photoUrl,
                        firstTransactionAmount: max(0, (refreshed.firstTransactionAmount ?? 0) - refundAmountValue),
                        amountReceived: max(0, (refreshed.amountReceived ?? 0) - refundAmountValue),
                        outstandingAmount: max(0, (refreshed.outstandingAmount ?? 0)),
                        conversionProbability: refreshed.conversionProbability,
                        remainingSessions: refreshed.remainingSessions
                    )
                    _ = try await CustomerService.shared.updateCustomer(id: customer.id, data: update)
                }
                
                isSaving = false
                onCancel()
                onSave()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct AddPaymentSheet: View {
    let customer: Customer
    let transactions: [Transaction]
    let transaction: Transaction?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var userState: UserState
    @State private var selectedTransactionId: UUID?
    @State private var paymentAmount: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var selectedTransaction: Transaction? {
        if let transaction = transaction { return transaction }
        return transactions.first { $0.id == selectedTransactionId }
    }
    
    private var paymentAmountValue: Double {
        Double(paymentAmount) ?? 0
    }
    
    private var canSave: Bool {
        paymentAmountValue > 0 && selectedTransaction != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("选择收款对应成交") {
                    if let transaction = transaction {
                        Text("\(transaction.packageName ?? "未知套餐") · 待收 ¥\(String(format: "%.0f", transaction.outstandingAmount ?? 0))")
                    } else if transactions.isEmpty {
                        Text("没有可收款的成交记录")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("成交记录", selection: $selectedTransactionId) {
                            ForEach(transactions.filter { ($0.outstandingAmount ?? 0) > 0 }) { tx in
                                Text("\(tx.packageName ?? "未知套餐") · 待收 ¥\(String(format: "%.0f", tx.outstandingAmount ?? 0))")
                                    .tag(tx.id as UUID?)
                            }
                        }
                    }
                }
                
                Section("收款信息") {
                    TextField("收款金额 (¥)", text: $paymentAmount)
                        .keyboardType(.decimalPad)
                    TextField("收款备注（选填）", text: $notes)
                }
                
                Section {
                    Button {
                        savePayment()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("确认收款")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSave || isSaving)
                    .foregroundColor(.green)
                }
            }
            .navigationTitle("新增收款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { onCancel() }
                }
            }
            .alert("收款失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let transaction = transaction {
                    selectedTransactionId = transaction.id
                } else if selectedTransactionId == nil {
                    selectedTransactionId = transactions.first { ($0.outstandingAmount ?? 0) > 0 }?.id
                }
            }
        }
    }
    
    private func savePayment() {
        guard paymentAmountValue > 0 else { return }
        guard let storeId = customer.associatedStoreId ?? userState.storeId else {
            errorMessage = "客户未分配门店"
            showError = true
            return
        }
        guard let targetTx = selectedTransaction else {
            errorMessage = "请选择要收款的成交记录"
            showError = true
            return
        }
        
        isSaving = true
        Task {
            do {
                let payment = TransactionInsert(
                    customerId: customer.id,
                    storeId: storeId,
                    packageId: targetTx.packageId,
                    staffUserId: userState.currentUser?.id,
                    amount: 0,
                    amountReceived: paymentAmountValue,
                    outstandingAmount: 0,
                    totalSessions: 0,
                    transactionDate: Date(),
                    estimatedCompletionDate: nil,
                    status: .paid,
                    notes: notes.isEmpty ? "收款 · \(targetTx.packageName ?? "")" : "收款 · \(targetTx.packageName ?? "")：\(notes)"
                )
                _ = try await TransactionService.shared.createTransaction(payment)
                
                // 同步减少原成交的待收
                let newOutstanding = max(0, (targetTx.outstandingAmount ?? 0) - paymentAmountValue)
                let newReceived = (targetTx.amountReceived ?? 0) + paymentAmountValue
                _ = try? await TransactionService.shared.updateTransaction(
                    id: targetTx.id.uuidString,
                    data: TransactionUpdate(amountReceived: newReceived, outstandingAmount: newOutstanding)
                )
                
                // 同步刷新客户档案财务字段
                if let refreshed = try? await CustomerService.shared.getCustomer(id: customer.id) {
                    let update = CustomerInsert(
                        phone: refreshed.phone,
                        name: refreshed.name,
                        gender: refreshed.gender,
                        birthdate: refreshed.birthdate,
                        medicalHistory: refreshed.medicalHistory,
                        preferences: refreshed.preferences,
                        associatedStoreId: refreshed.associatedStoreId,
                        photoUrl: refreshed.photoUrl,
                        firstTransactionAmount: refreshed.firstTransactionAmount,
                        amountReceived: (refreshed.amountReceived ?? 0) + paymentAmountValue,
                        outstandingAmount: max(0, (refreshed.outstandingAmount ?? 0) - paymentAmountValue),
                        conversionProbability: refreshed.conversionProbability,
                        remainingSessions: refreshed.remainingSessions
                    )
                    _ = try await CustomerService.shared.updateCustomer(id: customer.id, data: update)
                }
                
                isSaving = false
                onCancel()
                onSave()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        CustomerDetailView(
            customer: Customer(
                id: UUID(),
                phone: "13800138000",
                name: "张女士",
                gender: "female",
                birthdate: "1990-01-01",
                medicalHistory: "对玻尿酸过敏",
                preferences: ["偏好项目": "水光针"],
                photoUrl: nil,
                associatedStoreId: nil,
                createdBy: nil,
                lastVisit: nil,
                firstTransactionAmount: 5000,
                amountReceived: 2000,
                outstandingAmount: 3000,
                conversionProbability: nil,
                remainingSessions: 5,
                createdAt: nil,
                updatedAt: nil
            ),
            stores: []
        )
    }
}
