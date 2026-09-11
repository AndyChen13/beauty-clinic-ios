// Views/TransactionEditSheet.swift
import SwiftUI

struct TransactionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    let onUpdated: () -> Void
    let onDeleted: () -> Void
    
    init(transaction: Transaction, onUpdated: @escaping () -> Void, onDeleted: @escaping () -> Void = {}) {
        self.transaction = transaction
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
    }
    
    @State private var amountString: String = ""
    @State private var amountReceivedString: String = ""
    @State private var totalSessionsString: String = ""
    @State private var branch: TransactionBranch = .photoElectric
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showApprovalAlert = false
    @State private var approvalMessage = ""
    
    private var isRefund: Bool {
        transaction.status == .refunded
    }
    
    private var canSave: Bool {
        guard let amount = Double(amountString),
              let totalSessions = Int(totalSessionsString) else {
            return false
        }
        
        if isRefund {
            return amount > 0
                && totalSessions >= 0
                && !isSaving
        } else {
            guard let amountReceived = Double(amountReceivedString) else {
                return false
            }
            return amount >= 0
                && amountReceived >= 0
                && amountReceived <= amount
                && totalSessions >= transaction.completedSessions
                && !isSaving
        }
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
                    Text("应交付次数：\(transaction.totalSessions) 次  ·  已交付：\(transaction.completedSessions) 次")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("修改字段") {
                    Picker("成交归属", selection: $branch) {
                        ForEach(TransactionBranch.allCases, id: \.self) { b in
                            Text(b.displayName).tag(b)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text(isRefund ? "退款金额" : "成交金额")
                        Spacer()
                        TextField("0", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    if !isRefund {
                        HStack {
                            Text("已收金额")
                            Spacer()
                            TextField("0", text: $amountReceivedString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                    }
                    
                    HStack {
                        Text(isRefund ? "退款次数" : "应交付次数")
                        Spacer()
                        TextField("0", text: $totalSessionsString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("备注")
                        Spacer()
                        TextField("输入备注", text: $notes)
                            .multilineTextAlignment(.trailing)
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
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除该成交记录")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(isRefund ? "修改退款" : "修改成交")
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
                if isRefund {
                    amountString = String(format: "%.0f", abs(transaction.amount))
                    amountReceivedString = String(format: "%.0f", abs(transaction.amountReceived ?? 0))
                    totalSessionsString = String(abs(transaction.totalSessions))
                } else {
                    amountString = String(format: "%.0f", transaction.amount)
                    amountReceivedString = String(format: "%.0f", transaction.amountReceived ?? 0)
                    totalSessionsString = String(transaction.totalSessions)
                }
                branch = transaction.branch
                notes = transaction.notes ?? ""
            }
            .confirmationDialog("确认删除成交记录？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    Task { await deleteTransaction() }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("删除后无法恢复，关联的交付记录也将被一并删除。")
            }
            .alert("已提交审批请求", isPresented: $showApprovalAlert) {
                Button("确定") { dismiss() }
            } message: {
                Text(approvalMessage)
            }
        }
    }
    
    private func save() async {
        guard let amount = Double(amountString),
              let totalSessions = Int(totalSessionsString) else {
            errorMessage = "金额或次数格式不正确"
            return
        }
        
        let finalAmount: Double
        let finalAmountReceived: Double?
        let finalTotalSessions: Int
        
        if isRefund {
            guard totalSessions >= 0 else {
                errorMessage = "退款次数不能为负数"
                return
            }
            finalAmount = -amount
            finalAmountReceived = -amount
            finalTotalSessions = -totalSessions
        } else {
            guard let amountReceived = Double(amountReceivedString) else {
                errorMessage = "金额格式不正确"
                return
            }
            guard amountReceived <= amount else {
                errorMessage = "已收金额不能大于成交金额"
                return
            }
            guard totalSessions >= transaction.completedSessions else {
                errorMessage = "应交付次数不能少于已交付次数（\(transaction.completedSessions) 次）"
                return
            }
            finalAmount = amount
            finalAmountReceived = amountReceived
            finalTotalSessions = totalSessions
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let update = TransactionUpdate(
                amount: finalAmount,
                amountReceived: finalAmountReceived,
                branch: branch,
                totalSessions: finalTotalSessions,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )
            _ = try await TransactionService.shared.updateTransaction(
                id: transaction.id.uuidString,
                data: update
            )
            dismiss()
            onUpdated()
        } catch {
            if case APIError.pendingApproval(let msg) = error {
                approvalMessage = msg
                showApprovalAlert = true
            } else {
                errorMessage = "保存失败：\(error.localizedDescription)"
            }
        }
        
        isSaving = false
    }
    
    private func deleteTransaction() async {
        do {
            try await TransactionService.shared.deleteTransaction(id: transaction.id.uuidString)
            dismiss()
            onDeleted()
        } catch {
            if case APIError.pendingApproval(let msg) = error {
                approvalMessage = msg
                showApprovalAlert = true
            } else {
                errorMessage = "删除失败：\(error.localizedDescription)"
            }
        }
    }
}
