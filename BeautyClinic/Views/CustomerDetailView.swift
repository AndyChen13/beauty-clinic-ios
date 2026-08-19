// CustomerDetailView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct CustomerDetailView: View {
    let customer: Customer
    
    @State private var isEditing = false
    
    var body: some View {
        Form {
            Section("基本信息") {
                TextField("姓名", text: .constant(customer.name))
                TextField("手机号", text: .constant(customer.phone))
                
                Picker("性别", selection: .constant(customer.gender ?? "male")) {
                    Text("男").tag("male")
                    Text("女").tag("female")
                    Text("其他").tag("other")
                }
                
                DatePicker("出生日期", selection: .constant(customer.birthdate ?? Date()))
            }
            
            Section("医疗记录") {
                TextField("过敏史/病史", text: .constant(customer.medical_history ?? ""))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3...)
            }
            
            Section("备注") {
                TextEditor(text: .constant(customer.preferencesString))
                    .frame(height: 100)
            }
        }
        .navigationTitle(customer.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

#Preview {
    CustomerDetailView(customer: Customer(phone: "13800138000", name: "张女士"))
}