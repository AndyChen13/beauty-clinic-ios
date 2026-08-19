// CustomerEditView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct CustomerEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let customer: Customer?
    
    @State private var name = ""
    @State private var phone = ""
    @State private var gender = "male"
    @State private var birthdate = Date()
    @State private var medicalHistory = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名", text: $name)
                    
                    TextField("手机号", text: $phone)
                        .keyboardType(.phonePad)
                        .textInputAutocapitalization(.never)
                    
                    Picker("性别", selection: $gender) {
                        Text("男").tag("male")
                        Text("女").tag("female")
                        Text("其他").tag("other")
                    }
                    
                    DatePicker("出生日期", selection: $birthdate)
                }
                
                Section("医疗记录") {
                    TextField("过敏史/病史", text: $medicalHistory)
                }
                
                Section("备注") {
                    TextField("客户偏好与注意事项", text: $notes)
                }
            }
            .navigationTitle(customer == nil ? "添加客户" : "编辑客户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCustomer() }
                }
            }
        }
    }
    
    private func saveCustomer() {
        // TODO: Implement customer save logic
        dismiss()
    }
}

#Preview {
    CustomerEditView(customer: nil)
}