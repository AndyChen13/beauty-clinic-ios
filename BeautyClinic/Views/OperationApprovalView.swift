// Views/OperationApprovalView.swift
import SwiftUI

struct OperationApprovalView: View {
    @EnvironmentObject var userState: UserState
    @State private var approvals: [OperationApproval] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedApproval: OperationApproval?
    @State private var showDetail = false
    @State private var adminNote = ""

    var body: some View {
        NavigationStack {
            List {
                if !approvals.isEmpty {
                    Section("待审批操作 (\(approvals.count))") {
                        ForEach(approvals) { approval in
                            ApprovalRow(approval: approval)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedApproval = approval
                                    adminNote = ""
                                    showDetail = true
                                }
                        }
                    }
                }

                if approvals.isEmpty && !isLoading {
                    Section {
                        EmptyStateView(
                            icon: "checkmark.shield",
                            title: "暂无待审批操作",
                            subtitle: "员工提交的修改/删除申请会显示在这里"
                        )
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("操作审批")
            .refreshable { await loadApprovals() }
            .task { await loadApprovals() }
            .sheet(isPresented: $showDetail) {
                if let approval = selectedApproval {
                    OperationApprovalDetailSheet(
                        approval: approval,
                        adminNote: $adminNote,
                        onApprove: { approve(approval) },
                        onReject: { reject(approval) }
                    )
                }
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func loadApprovals() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await AdminService.shared.listPendingApprovals()
            approvals = list
        } catch {
            print("加载待审批操作失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func approve(_ approval: OperationApproval) {
        Task {
            do {
                try await AdminService.shared.approveOperation(id: approval.id, notes: adminNote.isEmpty ? nil : adminNote)
                await loadApprovals()
            } catch {
                errorMessage = "审批失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func reject(_ approval: OperationApproval) {
        Task {
            do {
                try await AdminService.shared.rejectOperation(id: approval.id, notes: adminNote.isEmpty ? nil : adminNote)
                await loadApprovals()
            } catch {
                errorMessage = "拒绝失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct ApprovalRow: View {
    let approval: OperationApproval

    private var targetDisplay: String {
        switch approval.targetType {
        case "transaction": return "交易"
        case "service_record": return "服务记录"
        default: return approval.targetType
        }
    }

    private var operationDisplay: String {
        switch approval.operationType {
        case "update": return "修改"
        case "delete": return "删除"
        default: return approval.operationType
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("\(targetDisplay) · \(operationDisplay)")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text(requesterText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(approval.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text("待审批")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .foregroundColor(.orange)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var requesterText: String {
        if let name = approval.requestedByName, !name.isEmpty {
            return "申请人: \(name)"
        }
        return "申请人"
    }
}

struct OperationApprovalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let approval: OperationApproval
    @Binding var adminNote: String
    let onApprove: () -> Void
    let onReject: () -> Void

    private var targetDisplay: String {
        switch approval.targetType {
        case "transaction": return "交易"
        case "service_record": return "服务记录"
        default: return approval.targetType
        }
    }

    private var operationDisplay: String {
        switch approval.operationType {
        case "update": return "修改"
        case "delete": return "删除"
        default: return approval.operationType
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("申请信息") {
                    InfoRow(label: "目标类型", value: targetDisplay)
                    InfoRow(label: "操作类型", value: operationDisplay)
                    InfoRow(label: "申请人", value: approval.requestedByName ?? "未知")
                    InfoRow(label: "申请时间", value: approval.createdAt?.formatted() ?? "未知")
                    if !payloadText.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("变更内容")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(payloadText)
                                .font(.subheadline)
                        }
                    }
                }

                Section("审批备注") {
                    TextEditor(text: $adminNote)
                        .frame(minHeight: 80)
                }

                Section {
                    Button(role: operationDisplay == "删除" ? .destructive : .none) {
                        onApprove()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text(operationDisplay == "删除" ? "同意删除" : "同意修改")
                            Spacer()
                        }
                    }

                    Button {
                        onReject()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("驳回申请")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("审批详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var payloadText: String {
        guard let payload = approval.payload, !payload.isEmpty else { return "" }
        return payload
            .sorted { $0.key < $1.key }
            .map { "\(fieldDisplayName($0.key)): \($0.value.description)" }
            .joined(separator: "\n")
    }

    private func fieldDisplayName(_ key: String) -> String {
        switch key {
        case "amount": return "成交金额"
        case "amount_received": return "已收金额"
        case "store_rebate_amount": return "门店返利"
        case "total_sessions": return "应交付次数"
        case "branch": return "成交归属"
        case "notes": return "备注"
        case "sessions_used": return "消耗次数"
        case "operator_name": return "操作人"
        case "body_part": return "操作部位"
        case "service_details": return "服务记录"
        case "customer_feedback": return "客户反馈"
        case "extra_payment": return "额外付款"
        default: return key
        }
    }
}

#Preview {
    OperationApprovalView()
        .environmentObject(UserState())
}
