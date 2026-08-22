// Views/ServiceRecordEditView.swift
import SwiftUI
import PhotosUI

struct ServiceRecordEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userState: UserState
    
    let customer: Customer
    let transactions: [Transaction]
    let onSave: (ServiceRecord) -> Void
    
    @State private var selectedTransactionId: UUID?
    @State private var serviceDate = Date()
    @State private var operatorName = ""
    @State private var operatorPhone = ""
    @State private var bodyPart = ""
    @State private var customerFeedback = ""
    @State private var extraPayment = ""
    @State private var extraPaymentNote = ""
    @State private var sessionsUsed = "1"
    @State private var extraSessions = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var customerTransactions: [Transaction] {
        transactions.filter { $0.customerId == customer.id }
    }
    
    /// 当前客户剩余次数（从客户档案读取）
    private var currentRemaining: Int {
        customer.remainingSessions ?? 0
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
                Section("服务信息") {
                    if !customerTransactions.isEmpty {
                        Picker("关联成交", selection: $selectedTransactionId) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(customerTransactions) { t in
                                Text("\(t.packageName ?? "套餐") (¥\(Int(t.amount)))").tag(t.id as UUID?)
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
                
                Section("服务详情") {
                    TextField("操作部位 *", text: $bodyPart)
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
                    if !photoDataList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoDataList.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: photoDataList[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                        Label(photoDataList.isEmpty ? "添加照片" : "继续添加", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        Task {
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    photoDataList.append(data)
                                }
                            }
                            selectedPhotos = []
                        }
                    }
                }
            }
            .navigationTitle("添加服务记录")
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
                    .disabled(operatorName.isEmpty || bodyPart.isEmpty || isSaving)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                operatorName = userState.currentUser?.name ?? ""
            }
        }
    }
    
    private func saveRecord() {
        guard !operatorName.isEmpty, !bodyPart.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                var photoUrls: [String] = []
                
                // Upload photos
                for photoData in photoDataList {
                    let fileName = "service-\(UUID().uuidString).jpg"
                    let url = try await TencentCOSUploadService.uploadImage(photoData, key: fileName)
                    photoUrls.append(url)
                }
                
                let extraPaymentValue = Double(extraPayment) ?? 0
                let newRemaining = calculatedRemaining
                
                let record = ServiceRecordInsert(
                    customerId: customer.id,
                    transactionId: selectedTransactionId,
                    serviceDate: serviceDate,
                    operatorId: userState.currentUser?.id,
                    operatorName: operatorName,
                    operatorPhone: operatorPhone.isEmpty ? nil : operatorPhone,
                    bodyPart: bodyPart,
                    photos: photoUrls.isEmpty ? nil : photoUrls,
                    customerFeedback: customerFeedback.isEmpty ? nil : customerFeedback,
                    extraPayment: extraPaymentValue,
                    extraPaymentNote: extraPaymentNote.isEmpty ? nil : extraPaymentNote,
                    sessionsUsed: sessionsUsedValue,
                    remainingSessions: newRemaining
                )
                
                let created: [ServiceRecord] = try await supabase
                    .from("service_records")
                    .insert(record)
                    .select()
                    .execute()
                    .value
                
                // Update customer remaining_sessions and last_visit
                struct CustomerRemainingUpdate: Encodable {
                    let remaining_sessions: Int
                    let last_visit: String
                }
                
                let customerUpdate = CustomerRemainingUpdate(
                    remaining_sessions: newRemaining,
                    last_visit: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await supabase
                    .from("customers")
                    .update(customerUpdate)
                    .eq("id", value: customer.id)
                    .execute()
                
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
    ServiceRecordEditView(
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
