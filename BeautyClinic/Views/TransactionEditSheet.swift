// Views/TransactionEditSheet.swift
import SwiftUI

struct TransactionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    let onUpdated: () -> Void
    
    @State private var amountString: String = ""
    @State private var amountReceivedString: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private var canSave: Bool {
        guard let amount = Double(amountString),
              let amountReceived = Double(amountReceivedString) else {
            return false
        }
        return amount >= 0 && amountReceived >= 0 && amountReceived <= amount && !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("成交信息") {
                    Text(transaction.packageName ?? "未知套餐")
                        .font(.headline)
                    Text("当前成交金额：¥\(String(format: "%.0f", transaction.amount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("当前已收：¥\(String(format: "%.0f", transaction.amountReceived ?? 0))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("修改字段") {
                    HStack {
                        Text("成交金额")
                        Spacer()
                        TextField("0", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("已收金额")
                        Spacer()
                        TextField("0", text: $amountReceivedString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("修改记录") {
                    if let logs = transaction.auditLogs, !logs.isEmpty {
                        ForEach(logs) { log in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(log.fieldDisplayName)：¥\(log.oldValue ?? "-") → ¥\(log.newValue ?? "-")")
                                    .font(.subheadline)
                                Text("\(log.editedByName ?? "未知用户") · \(log.editedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        Text("暂无修改记录")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("修改成交")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                amountString = String(format: "%.0f", transaction.amount)
                amountReceivedString = String(format: "%.0f", transaction.amountReceived ?? 0)
                notes = transaction.notes ?? ""
            }
        }
    }
    
    private func save() async {
        guard let amount = Double(amountString),
              let amountReceived = Double(amountReceivedString) else {
            errorMessage = "金额格式不正确"
            return
        }
        
        guard amountReceived <= amount else {
            errorMessage = "已收金额不能大于成交金额"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let update = TransactionUpdate(
                amount: amount,
                amountReceived: amountReceived,
                notes: notes.isEmpty ? nil : notes
            )
            _ = try await TransactionService.shared.updateTransaction(
                id: transaction.id.uuidString,
                data: update
            )
            dismiss()
            onUpdated()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
        
        isSaving = false
    }
}
