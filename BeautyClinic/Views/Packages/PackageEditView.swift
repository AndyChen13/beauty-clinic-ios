// PackageEditView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct PackageEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let package: Package?
    
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var category = "skin"
    @State private var price = ""
    @State private var durationMinutes = 60
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("套餐名称", text: $name)
                    
                    Picker("分类", selection: $category) {
                        Text("皮肤管理").tag("skin")
                        Text("身体护理").tag("body")
                        Text("面部美容").tag("face")
                        Text("头发护理").tag("hair")
                    }
                    
                    TextField("价格 (元)", text: $price)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                    
                    Stepper("时长: \(durationMinutes) 分钟", value: $durationMinutes, in: 15...300, step: 15)
                }
                
                Section("描述") {
                    TextField("描述 (可选)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle(package == nil ? "添加套餐" : "编辑套餐")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { savePackage() }
                }
            }
        }
    }
    
    private func savePackage() {
        // TODO: Implement package save logic
        dismiss()
    }
}

#Preview {
    PackageEditView()
}