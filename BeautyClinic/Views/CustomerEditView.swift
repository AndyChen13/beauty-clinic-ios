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
    
    @State private var name = ""
    @State private var phone = ""
    @State private var gender = "female"
    @State private var birthdate = Date()
    @State private var hasBirthdate = false
    @State private var medicalHistory = ""
    @State private var notes = ""
    @State private var selectedStoreId: UUID?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                
                Section("基本信息") {
                    TextField("姓名 *", text: $name)
                    
                    TextField("手机号 *", text: $phone)
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
                    
                    Toggle("已填写生日", isOn: $hasBirthdate)
                    if hasBirthdate {
                        DatePicker("出生日期", selection: $birthdate, displayedComponents: .date)
                    }
                }
                
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
                
                Section("医疗记录") {
                    TextEditor(text: $medicalHistory)
                        .frame(minHeight: 80)
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
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
                    .disabled(name.isEmpty || phone.count < 11 || isSaving)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
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
                    if let prefs = customer.preferences {
                        notes = prefs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                    }
                } else {
                    selectedStoreId = userState.storeId
                }
            }
        }
    }
    
    private func saveCustomer() {
        guard !name.isEmpty, phone.count >= 11 else { return }
        
        isSaving = true
        
        Task {
            do {
                var photoUrl: String?
                
                // Upload photo if selected
                if let photoData = photoData {
                    let fileName = "\(UUID().uuidString).jpg"
                    let _ = try await supabase.storage
                        .from("customer-photos")
                        .upload(fileName, data: photoData)
                    
                    photoUrl = try supabase.storage
                        .from("customer-photos")
                        .getPublicURL(path: fileName)
                        .absoluteString
                }
                
                let customerData = CustomerInsert(
                    phone: phone,
                    name: name,
                    gender: gender,
                    birthdate: hasBirthdate ? formatDate(birthdate) : nil,
                    medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
                    preferences: notes.isEmpty ? nil : parseNotes(notes),
                    associatedStoreId: selectedStoreId
                )
                
                var created: Customer
                if case .edit(let existing) = mode {
                    struct CustomerUpdate: Encodable {
                        let phone: String
                        let name: String
                        let gender: String
                        let associated_store_id: String?
                        let medical_history: String?
                        let preferences: [String: String]?
                        let birthdate: String?
                        let photo_url: String?
                    }
                    
                    let updateData = CustomerUpdate(
                        phone: phone,
                        name: name,
                        gender: gender,
                        associated_store_id: selectedStoreId?.uuidString,
                        medical_history: medicalHistory.isEmpty ? nil : medicalHistory,
                        preferences: notes.isEmpty ? nil : parseNotes(notes),
                        birthdate: hasBirthdate ? formatDate(birthdate) : nil,
                        photo_url: photoUrl
                    )
                    
                    let result: [Customer] = try await supabase
                        .from("customers")
                        .update(updateData)
                        .eq("id", value: existing.id)
                        .select()
                        .execute()
                        .value
                    created = result.first!
                } else {
                    let result: [Customer] = try await supabase
                        .from("customers")
                        .insert(customerData)
                        .select()
                        .execute()
                        .value
                    created = result.first!
                    
                    // Upload photo after customer creation if needed
                    if let photoUrl = photoUrl {
                        try await supabase
                            .from("customers")
                            .update(["photo_url": photoUrl])
                            .eq("id", value: created.id)
                            .execute()
                        created = Customer(
                            id: created.id,
                            phone: created.phone,
                            name: created.name,
                            gender: created.gender,
                            birthdate: created.birthdate,
                            medicalHistory: created.medicalHistory,
                            preferences: created.preferences,
                            photoUrl: photoUrl,
                            associatedStoreId: created.associatedStoreId,
                            createdBy: created.createdBy,
                            lastVisit: created.lastVisit,
                            createdAt: created.createdAt,
                            updatedAt: created.updatedAt
                        )
                    }
                }
                
                onSave(created)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
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
}

#Preview {
    CustomerEditView(mode: .create, stores: []) { _ in }
        .environmentObject(UserState())
}
