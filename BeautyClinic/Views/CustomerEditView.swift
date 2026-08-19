//  Views/CustomerEditView.swift
//  BeautyClinic
//

import SwiftUI

enum CustomerEditMode {
    case create
    case edit(Customer)
}

struct CustomerEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: CustomerEditMode
    let onSave: (Customer) -> Void
    
    @State private var name = ""
    @State private var phone = ""
    @State private var gender = "female"
    @State private var birthdate = Date()
    @State private var hasBirthdate = false
    @State private var medicalHistory = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var navigationTitle: String {
        isEditing ? "编辑客户" : "添加客户"
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                
                Section("医疗记录") {
                    TextEditor(text: $medicalHistory)
                        .frame(minHeight: 80)
                    if medicalHistory.isEmpty {
                        Text("过敏史、既往病史等...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, -60)
                    }
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                    if notes.isEmpty {
                        Text("客户偏好、来源渠道等...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, -40)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveCustomer) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
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
                    if let bd = customer.birthdate {
                        birthdate = bd
                        hasBirthdate = true
                    }
                    medicalHistory = customer.medicalHistory ?? ""
                    if let prefs = customer.preferences {
                        notes = prefs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                    }
                }
            }
        }
    }
    
    private func saveCustomer() {
        guard !name.isEmpty, phone.count >= 11 else { return }
        
        isSaving = true
        
        Task {
            do {
                let customerData = CustomerInsert(
                    phone: phone,
                    name: name,
                    gender: gender,
                    birthdate: hasBirthdate ? birthdate : nil,
                    medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
                    preferences: notes.isEmpty ? nil : parseNotes(notes),
                    associatedStoreId: nil
                )
                
                if case .edit(let existing) = mode {
                    let updated: Customer = try await supabase
                        .from("customers")
                        .update(customerData)
                        .eq("id", value: existing.id)
                        .select()
                        .single()
                        .execute()
                        .value
                    onSave(updated)
                } else {
                    let created: Customer = try await supabase
                        .from("customers")
                        .insert(customerData)
                        .select()
                        .single()
                        .execute()
                        .value
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
    CustomerEditView(mode: .create) { _ in }
}
