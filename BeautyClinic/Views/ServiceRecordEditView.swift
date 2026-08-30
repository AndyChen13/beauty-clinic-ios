// Views/ServiceRecordEditView.swift
import SwiftUI
import PhotosUI

struct ServiceRecordEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userState: UserState
    
    let record: ServiceRecord?
    let customer: Customer
    let transactions: [Transaction]
    let onSave: (ServiceRecord) -> Void
    
    private var isEditing: Bool { record != nil }
    
    @State private var selectedTransactionId: UUID?
    @State private var serviceDate = Date()
    @State private var operatorName = ""
    @State private var operatorPhone = ""
    @State private var bodyPart = ""
    @State private var serviceDetails = ""
    @State private var customerFeedback = ""
    @State private var extraPayment = ""
    @State private var extraPaymentNote = ""
    @State private var sessionsUsed = "1"
    @State private var extraSessions = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newPhotoDataList: [Data] = []
    @State private var existingPhotoUrls: [String] = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// 可消耗的剩余品类；编辑时始终包含原关联品类
    private var availableTransactions: [Transaction] {
        let all = transactions.filter { $0.customerId == customer.id }
        guard let record = record else {
            return all.filter { $0.remainingSessions > 0 }
        }
        return all.filter { $0.id == record.transactionId || $0.remainingSessions > 0 }
    }
    
    /// 当前剩余次数：若选了具体品类则显示该品类剩余，否则显示客户总剩余
    private var currentRemaining: Int {
        if let txId = selectedTransactionId,
           let tx = availableTransactions.first(where: { $0.id == txId }) {
            return tx.remainingSessions
        }
        return customer.remainingSessions ?? 0
    }
    
    /// 本次消耗次数
    private var sessionsUsedValue: Int {
        Int(sessionsUsed) ?? 0
    }
    
    /// 本次新增购买次数
    private var extraSessionsValue: Int {
        Int(extraSessions) ?? 0
    }
    
    /// 计算后的新剩余次数
    private var calculatedRemaining: Int {
        currentRemaining - sessionsUsedValue + extraSessionsValue
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("消耗剩余品类") {
                    if availableTransactions.isEmpty {
                        Text("当前无剩余品类可选，无法保存")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        Picker("选择品类", selection: $selectedTransactionId) {
                            ForEach(availableTransactions) { t in
                                Text("\(t.packageName ?? "套餐") 剩余 \(t.remainingSessions)/\(t.totalSessions) 次 · ¥\(Int(t.amount))")
                                    .tag(t.id as UUID?)
                            }
                        }
                    }
                    
                    DatePicker("服务时间", selection: $serviceDate)
                }
                
                Section("操作人信息") {
                    TextField("操作人姓名 *", text: $operatorName)
                    TextField("操作人联系方式", text: $operatorPhone)
                        .keyboardType(.phonePad)
                }
                
                Section("操作信息") {
                    TextField("操作部位 *", text: $bodyPart)
                }
                
                Section("服务记录") {
                    TextEditor(text: $serviceDetails)
                        .frame(minHeight: 80)
                }
                
                Section("客户反馈") {
                    TextEditor(text: $customerFeedback)
                        .frame(minHeight: 60)
                }
                
                Section("次数记录") {
                    HStack {
                        Text("当前剩余次数")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(currentRemaining)")
                            .font(.body.weight(.medium))
                    }
                    
                    TextField("本次消耗次数", text: $sessionsUsed)
                        .keyboardType(.numberPad)
                        .onChange(of: sessionsUsed) { _, newValue in
                            sessionsUsed = String(newValue.filter { $0.isNumber }.prefix(3))
                        }
                    
                    HStack {
                        Text("更新后剩余")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(calculatedRemaining)")
                            .font(.body.weight(.bold))
                            .foregroundColor(calculatedRemaining < 0 ? .red : .primary)
                    }
                    
                    if calculatedRemaining < 0 {
                        Text("注意：剩余次数将为负数，请确认消耗次数正确")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("额外付款") {
                    TextField("额外付款金额 (¥)", text: $extraPayment)
                        .keyboardType(.decimalPad)
                    
                    TextField("本次新增购买次数", text: $extraSessions)
                        .keyboardType(.numberPad)
                        .onChange(of: extraSessions) { _, newValue in
                            extraSessions = String(newValue.filter { $0.isNumber }.prefix(3))
                        }
                    
                    TextField("付款备注", text: $extraPaymentNote)
                }
                
                Section("照片留存") {
                    if !existingPhotoUrls.isEmpty || !newPhotoDataList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(existingPhotoUrls.indices, id: \.self) { index in
                                    if let url = URL(string: existingPhotoUrls[index]) {
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                default:
                                                    Color.gray
                                                }
                                            }
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            Button {
                                                existingPhotoUrls.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                                
                                ForEach(newPhotoDataList.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: newPhotoDataList[index]) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            Button {
                                                newPhotoDataList.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                        Label("添加照片", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        Task {
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    newPhotoDataList.append(data)
                                }
                            }
                            selectedPhotos = []
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑服务记录" : "添加服务记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveRecord) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(operatorName.isEmpty || bodyPart.isEmpty || selectedTransactionId == nil || isSaving)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadExistingRecord()
            }
        }
    }
    
    private func loadExistingRecord() {
        if let record = record {
            selectedTransactionId = record.transactionId
            serviceDate = record.serviceDate
            operatorName = record.operatorName ?? ""
            operatorPhone = record.operatorPhone ?? ""
            bodyPart = record.bodyPart ?? ""
            serviceDetails = record.serviceDetails ?? ""
            customerFeedback = record.customerFeedback ?? ""
            extraPayment = record.extraPayment > 0 ? String(format: "%.2f", record.extraPayment) : ""
            extraPaymentNote = record.extraPaymentNote ?? ""
            sessionsUsed = "\(record.sessionsUsed)"
            existingPhotoUrls = record.photos ?? []
        } else {
            operatorName = userState.currentUser?.name ?? ""
            if selectedTransactionId == nil, let first = availableTransactions.first {
                selectedTransactionId = first.id
            }
        }
    }
    
    private func saveRecord() {
        guard !operatorName.isEmpty, !bodyPart.isEmpty else { return }
        guard let transactionId = selectedTransactionId else {
            errorMessage = "请选择消耗的品类"
            showError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                var photoUrls: [String] = existingPhotoUrls
                
                // Upload new photos
                for photoData in newPhotoDataList {
                    let fileName = "service-\(UUID().uuidString).jpg"
                    let url = try await TencentCOSUploadService.uploadImage(photoData, key: fileName)
                    photoUrls.append(url)
                }
                
                let extraPaymentValue = Double(extraPayment) ?? 0
                let newRemaining = calculatedRemaining
                
                if let record = record {
                    let update = ServiceRecordUpdate(
                        transactionId: transactionId,
                        serviceDate: serviceDate,
                        operatorName: operatorName,
                        operatorPhone: operatorPhone,
                        bodyPart: bodyPart,
                        serviceDetails: serviceDetails,
                        photos: photoUrls,
                        customerFeedback: customerFeedback,
                        extraPayment: extraPaymentValue,
                        extraPaymentNote: extraPaymentNote,
                        sessionsUsed: sessionsUsedValue,
                        remainingSessions: newRemaining >= 0 ? newRemaining : 0
                    )
                    let updated = try await ServiceRecordService.shared.updateRecord(id: record.id, update)
                    onSave(updated)
                } else {
                    let recordInsert = ServiceRecordInsert(
                        customerId: customer.id,
                        transactionId: transactionId,
                        serviceDate: serviceDate,
                        operatorId: userState.currentUser?.id,
                        operatorName: operatorName,
                        operatorPhone: operatorPhone.isEmpty ? nil : operatorPhone,
                        bodyPart: bodyPart,
                        serviceDetails: serviceDetails.isEmpty ? nil : serviceDetails,
                        photos: photoUrls.isEmpty ? nil : photoUrls,
                        customerFeedback: customerFeedback.isEmpty ? nil : customerFeedback,
                        extraPayment: extraPaymentValue,
                        extraPaymentNote: extraPaymentNote.isEmpty ? nil : extraPaymentNote,
                        sessionsUsed: sessionsUsedValue,
                        remainingSessions: newRemaining >= 0 ? newRemaining : 0
                    )
                    let created = try await ServiceRecordService.shared.createRecord(recordInsert)
                    onSave(created)
                }
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
    ServiceRecordEditView(
        record: nil,
        customer: Customer(
            id: UUID(),
            phone: "13800138000",
            name: "张女士",
            gender: "female",
            birthdate: nil,
            medicalHistory: nil,
            preferences: nil,
            photoUrl: nil,
            associatedStoreId: nil,
            createdBy: nil,
            lastVisit: nil,
            firstTransactionAmount: nil,
            amountReceived: nil,
            outstandingAmount: 0,
            conversionProbability: 50,
            remainingSessions: 5,
            createdAt: nil,
            updatedAt: nil
        ),
        transactions: []
    ) { _ in }
    .environmentObject(UserState())
}
