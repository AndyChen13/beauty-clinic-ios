// Views/DeleteRequestSheet.swift
import SwiftUI

struct DeleteRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let itemName: String
    @Binding var reason: String
    let onSubmit: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("申请删除") {
                    Text("\(itemName)")
                        .font(.subheadline.weight(.medium))
                }
                
                Section("删除原因") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button(role: .destructive) {
                        onSubmit()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("提交删除申请")
                            Spacer()
                        }
                    }
                    .disabled(reason.isEmpty)
                }
            }
            .navigationTitle("删除申请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
