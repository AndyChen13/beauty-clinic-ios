// TransactionRecordView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct TransactionRecordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCustomerName = ""
    @State private var selectedPackageName = ""
    @State private var amount = ""
    @State private var notes = ""
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("客户信息") {
                    TextField("客户姓名", text: $selectedCustomerName)
                }
                
                Section("服务信息") {
                    TextField("套餐名称", text: $selectedPackageName)
                    
                    TextField("金额", text: $amount)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                    
                    DatePicker("预约时间", selection: $selectedDate)
                }
                
                Section("备注") {
                    TextField("其他说明", text: $notes)
                        .multilineTextAlignment(.leading)
                }
            }
            .navigationTitle("记录成交")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveTransaction() }
                }
            }
        }
    }
    
    private func saveTransaction() {
        // TODO: Implement transaction save logic
        dismiss()
    }
}

#Preview {
    TransactionRecordView()
}