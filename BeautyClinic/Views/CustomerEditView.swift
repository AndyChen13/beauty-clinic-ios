// Views/CustomerEditView.swift
import SwiftUI
import PhotosUI

enum CustomerEditMode {
    case create
    case edit(Customer)
}

struct CustomerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userState: UserState
    
    let mode: CustomerEditMode
    let stores: [Store]
    let onSave: (Customer) -> Void
    
    // 基本信息
    @State private var name = ""
    @State private var phone = ""
    @State private var gender = "female"
    @State private var birthdate = Date()
    @State private var hasBirthdate = false
    @State private var medicalHistory = ""
    @State private var notes = ""
    @State private var selectedTags: Set<CustomerTag> = [.photoElectric]
    @State private var selectedStoreId: UUID?
    
    // 创建模式成交
    @State private var useCustomDeal = false
    @State private var availablePackages: [ServicePackage] = []
    @State private var selectedPackageIds: Set<UUID> = []
    @State private var discount = ""
    @State private var discountSessions = ""
    @State private var firstTransactionDate = Date()
    @State private var hasFirstTransactionDate = false
    @State private var firstTransactionAmount = ""
    @State private var amountReceived = ""
    @State private var outstandingAmount = ""
    @State private var remainingSessions = ""
    
    // 编辑模式新增成交
    @State private var existingTransactions: [Transaction] = []
    @State private var showAddDeal = false
    @State private var newUseCustomDeal = false
    @State private var newSelectedPackageIds: Set<UUID> = []
    @State private var newDiscount = ""
    @State private var newDiscountSessions = ""
    @State private var newAmountReceived = ""
    @State private var newCustomAmount = ""
    @State private var newCustomReceived = ""
    @State private var newCustomSessions = ""
    @State private var newCustomNotes = ""
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isLoadingPackages = false
    @State private var isLoadingTransactions = false
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    // MARK: - 创建模式计算
    private var selectedPackages: [ServicePackage] {
        availablePackages.filter { selectedPackageIds.contains($0.id) }
    }
    
    private var packageSubtotal: Double {
        selectedPackages.reduce(0) { $0 + $1.price }
    }
    
    private var packageBaseSessions: Int {
        selectedPackages.reduce(0) { $0 + $1.totalSessions }
    }
    
    private var packageTotalSessions: Int {
        packageBaseSessions + discountSessionsValue
    }
    
    private var discountValue: Double {
        Double(discount) ?? 0
    }
    
    private var discountSessionsValue: Int {
        Int(discountSessions) ?? 0
    }
    
    private var computedFinalAmount: Double {
        max(0, packageSubtotal - discountValue)
    }
    
    private var computedOutstanding: Double {
        max(0, computedFinalAmount - (Double(amountReceived) ?? 0))
    }
    
    // MARK: - 编辑模式新增成交计算
    private var newSelectedPackages: [ServicePackage] {
        availablePackages.filter { newSelectedPackageIds.contains($0.id) }
    }
    
    private var newDealSubtotal: Double {
        newSelectedPackages.reduce(0) { $0 + $1.price }
    }
    
    private var newDealBaseSessions: Int {
        newSelectedPackages.reduce(0) { $0 + $1.totalSessions }
    }
    
    private var newDealDiscountValue: Double {
        Double(newDiscount) ?? 0
    }
    
    private var newDealDiscountSessionsValue: Int {
        Int(newDiscountSessions) ?? 0
    }
    
    private var newDealFinalAmount: Double {
        max(0, newDealSubtotal - newDealDiscountValue)
    }
    
    private var newDealTotalSessions: Int {
        newDealBaseSessions + newDealDiscountSessionsValue
    }
    
    private var newDealOutstanding: Double {
        max(0, newDealFinalAmount - (Double(newAmountReceived) ?? 0))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                basicInfoSection
                storeSection
                medicalSection
                notesSection
                if isEditing {
                    transactionHistorySection
                    addDealSection
                } else {
                    dealSection
                }
            }
            .navigationTitle(isEditing ? "编辑客户" : "添加客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveCustomer) {
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
            .onAppear {
                loadInitialData()
            }
        }
    }
    
    // MARK: - Sections
    
    private var avatarSection: some View {
        Section("头像") {
            HStack {
                Spacer()
                if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else if case .edit(let customer) = mode, let photoUrl = customer.photoUrl {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        AvatarView(name: name, size: 80)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    AvatarView(name: name, size: 80)
                }
                Spacer()
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text(photoData != nil ? "更换照片" : "选择照片")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section("基本信息") {
            TextField("姓名 *", text: $name)
            
            TextField("手机号", text: $phone)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .onChange(of: phone) { _, newValue in
                    phone = String(newValue.filter { $0.isNumber }.prefix(11))
                }
            
            Picker("性别", selection: $gender) {
                Text("女").tag("female")
                Text("男").tag("male")
                Text("其他").tag("other")
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("客户板块")
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(CustomerTag.allCases, id: \.self) { tag in
                        CustomerTagChip(
                            title: tag.displayName,
                            isSelected: selectedTags.contains(tag),
                            color: tag.color
                        ) {
                            toggleTag(tag)
                        }
                    }
                }
            }
            
            Toggle("已填写生日", isOn: $hasBirthdate)
            if hasBirthdate {
                DatePicker("出生日期", selection: $birthdate, displayedComponents: .date)
            }
        }
    }
    
    private var storeSection: some View {
        Section("归属门店") {
            if stores.isEmpty {
                Text("暂无门店可选")
                    .foregroundStyle(.secondary)
            } else {
                Picker("选择门店", selection: $selectedStoreId) {
                    Text("请选择门店").tag(nil as UUID?)
                    ForEach(stores) { store in
                        Text(store.name).tag(store.id as UUID?)
                    }
                }
            }
        }
    }
    
    private var medicalSection: some View {
        Section("身体情况") {
            TextEditor(text: $medicalHistory)
                .frame(minHeight: 80)
        }
    }
    
    private var notesSection: some View {
        Section("客户偏好 / 备注") {
            TextEditor(text: $notes)
                .frame(minHeight: 60)
        }
    }
    
    // MARK: - 成交历史（编辑模式只读 + 新增成交）
    
    private var transactionHistorySection: some View {
        Section("成交历史") {
            Toggle("自定义首次成交时间", isOn: $hasFirstTransactionDate)
            if hasFirstTransactionDate {
                DatePicker("首次成交时间", selection: $firstTransactionDate, displayedComponents: .date)
            }
            
            if isLoadingTransactions {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
            } else if existingTransactions.isEmpty {
                Text("暂无成交记录")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(label: "成交总额", value: "¥\(String(format: "%.0f", totalTransactionAmount))")
                    summaryRow(label: "已收款", value: "¥\(String(format: "%.0f", totalReceived))")
                    summaryRow(label: "待收款", value: "¥\(String(format: "%.0f", totalOutstanding))")
                    summaryRow(label: "总服务次数", value: "\(totalSessions) 次")
                    summaryRow(label: "剩余次数", value: "\(remainingSessionCount) 次")
                    Divider()
                    Text("套餐明细")
                        .font(.subheadline.weight(.medium))
                    ForEach(existingTransactions) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.packageName ?? "未知套餐")
                                    .font(.subheadline)
                                Text("\(transaction.completedSessions)/\(transaction.totalSessions) 次 · 剩余 \(transaction.remainingSessions) 次 · ¥\(String(format: "%.0f", transaction.amount))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transaction.status.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(transaction.status.color.opacity(0.15))
                                .foregroundColor(transaction.status.color)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    private var addDealSection: some View {
        Section("新增成交") {
            Toggle("添加本次成交", isOn: $showAddDeal)
            
            if showAddDeal {
                Toggle("自定义成交", isOn: $newUseCustomDeal)
                    .onChange(of: newUseCustomDeal) { _, isCustom in
                        if isCustom {
                            newSelectedPackageIds.removeAll()
                        } else {
                            newCustomAmount = ""
                            newCustomReceived = ""
                            newCustomSessions = ""
                            newCustomNotes = ""
                        }
                    }
                
                if newUseCustomDeal {
                    customNewDealFields
                } else {
                    packageNewDealFields
                }
            }
        }
    }
    
    private var packageNewDealFields: some View {
        Group {
            if isLoadingPackages {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
            } else if availablePackages.isEmpty {
                Text("暂无可用套餐，可切换到自定义成交")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(availablePackages) { package in
                    Button {
                        toggleNewPackage(package.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.name)
                                    .font(.subheadline.weight(.medium))
                                Text("\(package.totalSessions) 次 · ¥\(String(format: "%.0f", package.price))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: newSelectedPackageIds.contains(package.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(newSelectedPackageIds.contains(package.id) ? .accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if !newSelectedPackages.isEmpty {
                    Divider()
                    summaryRow(label: "套餐总价", value: "¥\(String(format: "%.0f", newDealSubtotal))")
                    TextField("本次折扣金额 (¥)", text: $newDiscount)
                        .keyboardType(.decimalPad)
                        .onChange(of: newDiscount) { _, _ in updateNewDealComputedValues() }
                    TextField("本次福利次数", text: $newDiscountSessions)
                        .keyboardType(.numberPad)
                        .onChange(of: newDiscountSessions) { _, _ in updateNewDealComputedValues() }
                    summaryRow(label: "本次成交金额", value: "¥\(String(format: "%.0f", newDealFinalAmount))")
                    TextField("本次已收款 (¥)", text: $newAmountReceived)
                        .keyboardType(.decimalPad)
                    summaryRow(label: "本次待收款", value: "¥\(String(format: "%.0f", newDealOutstanding))")
                    summaryRow(label: "本次总次数", value: "\(newDealTotalSessions) 次")
                }
            }
        }
    }
    
    private var customNewDealFields: some View {
        Group {
            TextField("成交金额 (¥)", text: $newCustomAmount)
                .keyboardType(.decimalPad)
            TextField("已收款 (¥)", text: $newCustomReceived)
                .keyboardType(.decimalPad)
                .onChange(of: newCustomReceived) { _, _ in updateNewCustomComputedValues() }
            summaryRow(label: "本次待收款", value: "¥\(String(format: "%.0f", newCustomOutstanding))")
            TextField("服务次数", text: $newCustomSessions)
                .keyboardType(.numberPad)
            TextField("成交备注", text: $newCustomNotes)
        }
    }
    
    private var newCustomOutstanding: Double {
        max(0, (Double(newCustomAmount) ?? 0) - (Double(newCustomReceived) ?? 0))
    }
    
    private var totalTransactionAmount: Double {
        existingTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private var totalReceived: Double {
        amountReceived.isEmpty ? 0 : (Double(amountReceived) ?? 0)
    }
    
    private var totalOutstanding: Double {
        outstandingAmount.isEmpty ? 0 : (Double(outstandingAmount) ?? 0)
    }
    
    private var totalSessions: Int {
        existingTransactions.reduce(0) { $0 + $1.totalSessions }
    }
    
    private var remainingSessionCount: Int {
        existingTransactions.reduce(0) { $0 + $1.remainingSessions }
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
    
    // MARK: - 初始成交（创建模式）
    
    private var dealSection: some View {
        Section("成交历史") {
            Toggle("自定义成交", isOn: $useCustomDeal)
            
            Toggle("自定义首次成交时间", isOn: $hasFirstTransactionDate)
            if hasFirstTransactionDate {
                DatePicker("首次成交时间", selection: $firstTransactionDate, displayedComponents: .date)
            }
            
            if useCustomDeal {
                customDealFields
            } else {
                packageDealFields
            }
        }
    }
    
    private var customDealFields: some View {
        Group {
            TextField("成交金额 (¥)", text: $firstTransactionAmount)
                .keyboardType(.decimalPad)
            TextField("已收款 (¥)", text: $amountReceived)
                .keyboardType(.decimalPad)
                .onChange(of: amountReceived) { _, _ in updateCustomOutstanding() }
            TextField("待收款 (¥)", text: $outstandingAmount)
                .keyboardType(.decimalPad)
            TextField("服务次数", text: $remainingSessions)
                .keyboardType(.numberPad)
        }
    }
    
    private var packageDealFields: some View {
        Group {
            if isLoadingPackages {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
            } else if availablePackages.isEmpty {
                Text("暂无可用套餐，请先创建套餐或切换到自定义成交")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(availablePackages) { package in
                    Button {
                        togglePackage(package.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.name)
                                    .font(.subheadline.weight(.medium))
                                Text("\(package.totalSessions) 次 · ¥\(String(format: "%.0f", package.price))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedPackageIds.contains(package.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedPackageIds.contains(package.id) ? .accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if !selectedPackages.isEmpty {
                    Divider()
                    summaryRow(label: "套餐总价", value: "¥\(String(format: "%.0f", packageSubtotal))")
                    TextField("折扣金额 (¥)", text: $discount)
                        .keyboardType(.decimalPad)
                        .onChange(of: discount) { _, _ in updatePackageComputedValues() }
                    TextField("折扣次数（福利）", text: $discountSessions)
                        .keyboardType(.numberPad)
                        .onChange(of: discountSessions) { _, _ in updatePackageComputedValues() }
                    summaryRow(label: "成交金额", value: "¥\(String(format: "%.0f", computedFinalAmount))")
                    TextField("已收款 (¥)", text: $amountReceived)
                        .keyboardType(.decimalPad)
                        .onChange(of: amountReceived) { _, _ in updatePackageComputedValues() }
                    summaryRow(label: "待收款", value: "¥\(String(format: "%.0f", computedOutstanding))")
                    summaryRow(label: "总服务次数", value: "\(packageTotalSessions) 次")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func togglePackage(_ id: UUID) {
        if selectedPackageIds.contains(id) {
            selectedPackageIds.remove(id)
        } else {
            selectedPackageIds.insert(id)
        }
        updatePackageComputedValues()
    }
    
    private func toggleNewPackage(_ id: UUID) {
        if newSelectedPackageIds.contains(id) {
            newSelectedPackageIds.remove(id)
        } else {
            newSelectedPackageIds.insert(id)
        }
        updateNewDealComputedValues()
    }
    
    private func updatePackageComputedValues() {
        firstTransactionAmount = String(format: "%.0f", computedFinalAmount)
        outstandingAmount = String(format: "%.0f", computedOutstanding)
        remainingSessions = "\(packageTotalSessions)"
    }
    
    private func updateNewDealComputedValues() {
        newAmountReceived = ""
    }
    
    private func updateNewCustomComputedValues() {
        // 自定义成交的待收款由 newCustomOutstanding 计算属性实时得出
    }
    
    private func updateCustomOutstanding() {
        guard let total = Double(firstTransactionAmount),
              let received = Double(amountReceived) else { return }
        outstandingAmount = String(format: "%.0f", max(0, total - received))
    }
    
    private func loadInitialData() {
        if case .edit(let customer) = mode {
            name = customer.name
            phone = customer.phone
            gender = customer.gender ?? "female"
            selectedStoreId = customer.associatedStoreId
            if let bdString = customer.birthdate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let bd = formatter.date(from: bdString) {
                    birthdate = bd
                    hasBirthdate = true
                }
            }
            medicalHistory = customer.medicalHistory ?? ""
            notes = customer.preferencesNotes
            selectedTags = Set(customer.branchTags)
            if let firstTxnDate = customer.firstTransactionDate {
                firstTransactionDate = firstTxnDate
                hasFirstTransactionDate = true
            }
            if let firstTxn = customer.firstTransactionAmount {
                firstTransactionAmount = String(format: "%.0f", firstTxn)
            }
            if let received = customer.amountReceived {
                amountReceived = String(format: "%.0f", received)
            }
            if let outstanding = customer.outstandingAmount {
                outstandingAmount = String(format: "%.0f", outstanding)
            }
            if let sessions = customer.remainingSessions {
                remainingSessions = String(sessions)
            }
            loadTransactions(for: customer.id)
            loadPackages()
        } else {
            selectedStoreId = userState.storeId
            loadPackages()
        }
    }
    
    private func loadPackages() {
        isLoadingPackages = true
        Task {
            do {
                let (packages, _) = try await PackageService.shared.listPackages(isActive: true)
                _ = await MainActor.run {
                    self.availablePackages = packages
                    self.isLoadingPackages = false
                }
            } catch {
                _ = await MainActor.run {
                    self.isLoadingPackages = false
                }
            }
        }
    }
    
    private func loadTransactions(for customerId: UUID) {
        isLoadingTransactions = true
        Task {
            do {
                let txs = try await TransactionService.shared.listTransactions(customerId: customerId.uuidString)
                _ = await MainActor.run {
                    self.existingTransactions = txs
                    self.isLoadingTransactions = false
                }
            } catch {
                _ = await MainActor.run {
                    self.isLoadingTransactions = false
                }
            }
        }
    }
    
    private func saveCustomer() {
        guard !name.isEmpty else { return }
        
        if !isEditing && !useCustomDeal && !selectedPackageIds.isEmpty && selectedStoreId == nil && userState.storeId == nil {
            errorMessage = "选择套餐成交时需要指定归属门店"
            showError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                var photoUrl: String?
                
                if let photoData = photoData {
                    let fileName = "customer-\(UUID().uuidString).jpg"
                    photoUrl = try await TencentCOSUploadService.uploadImage(photoData, key: fileName)
                }
                
                // 有成交时，客户档案的剩余次数由交易记录累计，避免双倍叠加
                let isPackageDeal = !isEditing && !useCustomDeal && !selectedPackageIds.isEmpty
                let hasDeal = isPackageDeal || useCustomDeal
                
                let insert = CustomerInsert(
                    phone: phone,
                    name: name,
                    gender: gender,
                    birthdate: hasBirthdate ? formatDate(birthdate) : nil,
                    medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
                    preferences: buildPreferences(),
                    associatedStoreId: selectedStoreId,
                    photoUrl: photoUrl,
                    firstTransactionDate: hasFirstTransactionDate ? firstTransactionDate : nil,
                    firstTransactionAmount: Double(firstTransactionAmount),
                    amountReceived: Double(amountReceived),
                    outstandingAmount: Double(outstandingAmount),
                    conversionProbability: nil,
                    remainingSessions: hasDeal ? nil : Int(remainingSessions)
                )
                
                var saved: Customer
                if case .edit(let existing) = mode {
                    // 先更新客户基本信息
                    saved = try await CustomerService.shared.updateCustomer(id: existing.id, data: insert)
                    
                    // 若添加了新成交，创建交易记录
                    if showAddDeal {
                        let storeId = selectedStoreId ?? userState.storeId ?? saved.associatedStoreId
                        guard let storeId = storeId else {
                            throw NSError(domain: "CustomerEdit", code: 1, userInfo: [NSLocalizedDescriptionKey: "新增成交需要指定归属门店"])
                        }
                        
                        if newUseCustomDeal {
                            let customAmount = Double(newCustomAmount) ?? 0
                            let customReceived = Double(newCustomReceived) ?? 0
                            let customOutstanding = max(0, customAmount - customReceived)
                            let customTransaction = TransactionInsert(
                                customerId: saved.id,
                                storeId: storeId,
                                packageId: nil,
                                staffUserId: userState.currentUser?.id,
                                amount: customAmount,
                                amountReceived: customReceived,
                                outstandingAmount: customOutstanding,
                                totalSessions: Int(newCustomSessions) ?? 0,
                                transactionDate: Date(),
                                estimatedCompletionDate: nil,
                                status: .confirmed,
                                notes: newCustomNotes.isEmpty ? "自定义成交" : newCustomNotes
                            )
                            _ = try await TransactionService.shared.createTransaction(customTransaction)
                        } else if !newSelectedPackageIds.isEmpty {
                            let totalReceived = Double(newAmountReceived) ?? 0
                            let totalOutstanding = newDealOutstanding
                            try await createDealTransactions(customerId: saved.id, storeId: storeId, packages: newSelectedPackages, discount: newDealDiscountValue, discountSessions: newDealDiscountSessionsValue, totalReceived: totalReceived, totalOutstanding: totalOutstanding)
                        }
                        
                        // 重新获取后端累计后的客户数据，再更新收款金额
                        let refreshed = try await CustomerService.shared.getCustomer(id: saved.id)
                        let oldReceived = Double(amountReceived) ?? 0
                        let oldOutstanding = Double(outstandingAmount) ?? 0
                        let newReceived = newUseCustomDeal ? (Double(newCustomReceived) ?? 0) : (Double(newAmountReceived) ?? 0)
                        let newOutstanding = newUseCustomDeal ? max(0, (Double(newCustomAmount) ?? 0) - newReceived) : newDealOutstanding
                        let updatedInsert = CustomerInsert(
                            phone: refreshed.phone,
                            name: refreshed.name,
                            gender: refreshed.gender,
                            birthdate: refreshed.birthdate,
                            medicalHistory: refreshed.medicalHistory,
                            preferences: refreshed.preferences,
                            associatedStoreId: refreshed.associatedStoreId,
                            photoUrl: refreshed.photoUrl,
                            firstTransactionDate: hasFirstTransactionDate ? firstTransactionDate : refreshed.firstTransactionDate,
                            firstTransactionAmount: refreshed.firstTransactionAmount,
                            amountReceived: oldReceived + newReceived,
                            outstandingAmount: oldOutstanding + newOutstanding,
                            conversionProbability: refreshed.conversionProbability,
                            remainingSessions: refreshed.remainingSessions
                        )
                        saved = try await CustomerService.shared.updateCustomer(id: existing.id, data: updatedInsert)
                    }
                } else {
                    saved = try await CustomerService.shared.createCustomer(insert)
                    
                    let storeId = selectedStoreId ?? userState.storeId ?? saved.associatedStoreId
                    
                    // 为每个选中套餐创建独立交易记录，服务次数按套餐拆分
                    if isPackageDeal, let storeId = storeId {
                        let totalReceived = Double(amountReceived) ?? 0
                        let totalOutstanding = Double(outstandingAmount) ?? 0
                        try await createDealTransactions(customerId: saved.id, storeId: storeId, packages: selectedPackages, discount: discountValue, discountSessions: discountSessionsValue, totalReceived: totalReceived, totalOutstanding: totalOutstanding)
                    }
                    
                    // 自定义成交也生成一条交易记录，packageId 传 nil，后端会关联占位套餐
                    if useCustomDeal, let storeId = storeId {
                        let customTransaction = TransactionInsert(
                            customerId: saved.id,
                            storeId: storeId,
                            packageId: nil,
                            staffUserId: userState.currentUser?.id,
                            amount: Double(firstTransactionAmount) ?? 0,
                            amountReceived: Double(amountReceived) ?? 0,
                            outstandingAmount: Double(outstandingAmount) ?? 0,
                            totalSessions: Int(remainingSessions) ?? 0,
                            transactionDate: Date(),
                            estimatedCompletionDate: nil,
                            status: .confirmed,
                            notes: "自定义成交"
                        )
                        _ = try await TransactionService.shared.createTransaction(customTransaction)
                    }
                    
                    // 重新获取累计后的客户数据返回
                    if hasDeal {
                        saved = try await CustomerService.shared.getCustomer(id: saved.id)
                    }
                }
                
                // 如果上传了头像但返回数据未更新，本地覆盖
                if let photoUrl = photoUrl, saved.photoUrl != photoUrl {
                    saved = Customer(
                        id: saved.id,
                        phone: saved.phone,
                        name: saved.name,
                        gender: saved.gender,
                        birthdate: saved.birthdate,
                        medicalHistory: saved.medicalHistory,
                        preferences: saved.preferences,
                        photoUrl: photoUrl,
                        associatedStoreId: saved.associatedStoreId,
                        createdBy: saved.createdBy,
                        lastVisit: saved.lastVisit,
                        firstTransactionAmount: saved.firstTransactionAmount,
                        amountReceived: saved.amountReceived,
                        outstandingAmount: saved.outstandingAmount,
                        conversionProbability: saved.conversionProbability,
                        remainingSessions: saved.remainingSessions,
                        createdAt: saved.createdAt,
                        updatedAt: saved.updatedAt
                    )
                }
                
                onSave(saved)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
    
    private func createDealTransactions(customerId: UUID, storeId: UUID, packages: [ServicePackage], discount: Double, discountSessions: Int, totalReceived: Double, totalOutstanding: Double) async throws {
        // 将整单已收款/待收款按比例分配到每个套餐交易上
        var remainingReceived = totalReceived
        var remainingOutstanding = totalOutstanding
        var totalPrice: Double = 0
        for package in packages { totalPrice += package.price }

        for (index, package) in packages.enumerated() {
            var notes: String? = nil
            if index == 0 {
                var parts: [String] = []
                if discount > 0 { parts.append("合并折扣：¥\(String(format: "%.0f", discount))") }
                if discountSessions > 0 { parts.append("福利次数：+\(discountSessions) 次") }
                if !parts.isEmpty { notes = parts.joined(separator: "；") }
            }
            let extraSessions = (index == 0) ? discountSessions : 0

            let ratio = totalPrice > 0 ? package.price / totalPrice : 1.0
            var allocatedReceived = min(remainingReceived, package.price)
            // 本次成交金额可能因折扣低于原价，已收款和待收款以实际可收上限为准
            allocatedReceived = min(allocatedReceived, package.price)
            let allocatedOutstanding = min(remainingOutstanding, package.price - allocatedReceived)
            remainingReceived -= allocatedReceived
            remainingOutstanding -= allocatedOutstanding

            let transaction = TransactionInsert(
                customerId: customerId,
                storeId: storeId,
                packageId: package.id,
                staffUserId: userState.currentUser?.id,
                amount: package.price,
                amountReceived: allocatedReceived,
                outstandingAmount: allocatedOutstanding,
                totalSessions: package.totalSessions + extraSessions,
                transactionDate: Date(),
                estimatedCompletionDate: nil,
                status: .confirmed,
                notes: notes
            )
            _ = try await TransactionService.shared.createTransaction(transaction)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseNotes(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        return result
    }
    
    private func buildPreferences() -> [String: String]? {
        var result = parseNotes(notes)
        let branch = CustomerTag.allCases
            .filter { selectedTags.contains($0) }
            .map { $0.rawValue }
            .joined(separator: ",")
        if !branch.isEmpty {
            result["branch"] = branch
        }
        return result.isEmpty ? nil : result
    }
    
    private func toggleTag(_ tag: CustomerTag) {
        if selectedTags.contains(tag) {
            // 至少保留一个标签
            if selectedTags.count > 1 {
                selectedTags.remove(tag)
            }
        } else {
            selectedTags.insert(tag)
        }
    }
}

#Preview {
    CustomerEditView(mode: .create, stores: []) { _ in }
        .environmentObject(UserState())
}
