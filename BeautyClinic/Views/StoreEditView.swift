// StoreEditView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct StoreEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let store: Store?
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var status = "active"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("门店名称", text: $name)
                    TextField("地址", text: $address)
                    TextField("联系电话", text: $phone)
                        .keyboardType(.phonePad)
                    
                    Picker("状态", selection: $status) {
                        Text("运营中").tag("active")
                        Text("筹备中").tag("pending")
                        Text("已关闭").tag("closed")
                    }
                }
            }
            .navigationTitle(store == nil ? "添加门店" : "编辑门店")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveStore() }
                }
            }
        }
    }
    
    private func saveStore() {
        // TODO: Implement store save logic
        dismiss()
    }
}

#Preview {
    StoreEditView(store: nil)
}