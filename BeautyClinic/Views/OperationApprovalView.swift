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

    private var isAdmin: Bool { userState.isAdmin }

    private var pendingApprovals: [OperationApproval] {
        approvals.filter { $0.status == .pending }
    }

    private var approvedApprovals: [OperationApproval] {
        approvals.filter { $0.status == .approved }
    }

    private var rejectedApprovals: [OperationApproval] {
        approvals.filter { $0.status == .rejected }
    }

    var body: some View {
        NavigationStack {
            List {
                if !pendingApprovals.isEmpty {
                    Section("待审批 (\(pendingApprovals.count))") {
                        ForEach(pendingApprovals) { approval in
                            ApprovalRow(approval: approval)
                                .contentShape(Rectangle())
                                .onTapGesture { show(approval) }
                        }
                    }
                }

                if !approvedApprovals.isEmpty {
                    Section("已通过") {
                        ForEach(approvedApprovals) { approval in
                            ApprovalRow(approval: approval)
                                .contentShape(Rectangle())
                                .onTapGesture { show(approval) }
                        }
                    }
                }

                if !rejectedApprovals.isEmpty {
                    Section("已驳回") {
                        ForEach(rejectedApprovals) { approval in
                            ApprovalRow(approval: approval)
                                .contentShape(Rectangle())
                                .onTapGesture { show(approval) }
                        }
                    }
                }

                if approvals.isEmpty && !isLoading {
                    Section {
                        EmptyStateView(
                            icon: "checkmark.shield",
                            title: isAdmin ? "暂无待审批操作" : "暂无审批记录",
                            subtitle: isAdmin
                                ? "员工提交的修改/删除申请会显示在这里"
                                : "你提交的申请通过后会显示在这里"
                        )
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle(isAdmin ? "操作审批" : "我的审批")
            .refreshable { await loadApprovals() }
            .task { await loadApprovals() }
            .sheet(isPresented: $showDetail) {
                if let approval = selectedApproval {
                    OperationApprovalDetailSheet(
                        approval: approval,
                        adminNote: $adminNote,
                        canApprove: isAdmin && approval.status == .pending,
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

    private func show(_ approval: OperationApproval) {
        selectedApproval = approval
        adminNote = ""
        showDetail = true
    }

    private func loadApprovals() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await isAdmin
                ? AdminService.shared.listAllApprovals()
                : AdminService.shared.listMyApprovals()
            approvals = list
        } catch {
            print("加载审批记录失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func approve(_ approval: OperationApproval) {
        Task {
            do {
                try await AdminService.shared.approveOperation(
                    id: approval.id,
                    notes: adminNote.isEmpty ? nil : adminNote
                )
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
                try await AdminService.shared.rejectOperation(
                    id: approval.id,
                    notes: adminNote.isEmpty ? nil : adminNote
                )
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
        case "customer": return "客户"
        case "store": return "门店"
        case "package": return "套餐"
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
                .fill(statusColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: statusIcon)
                        .font(.system(size: 14))
                        .foregroundColor(statusColor)
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

            Text(approval.status.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.12))
                .foregroundColor(statusColor)
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

    private var statusColor: Color {
        approval.status.color
    }

    private var statusIcon: String {
        switch approval.status {
        case .pending: return "clock"
        case .approved: return "checkmark"
        case .rejected: return "xmark"
        }
    }
}

struct OperationApprovalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let approval: OperationApproval
    @Binding var adminNote: String
    let canApprove: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    private var targetDisplay: String {
        switch approval.targetType {
        case "transaction": return "交易"
        case "service_record": return "服务记录"
        case "customer": return "客户"
        case "store": return "门店"
        case "package": return "套餐"
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

                if canApprove {
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
                } else {
                    Section("审批结果") {
                        InfoRow(label: "状态", value: approval.status.displayName)
                        if let reviewer = approval.reviewedByName, !reviewer.isEmpty {
                            InfoRow(label: "审批人", value: reviewer)
                        }
                        if let date = approval.reviewedAt {
                            InfoRow(label: "审批时间", value: date.formatted())
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
        case "customerName": return "客户姓名"
        case "storeName": return "门店名称"
        case "packageName": return "套餐名称"
        case "reason": return "删除原因"
        default: return key
        }
    }
}

extension ApprovalStatus {
    var displayName: String {
        switch self {
        case .pending: return "待审批"
        case .approved: return "已通过"
        case .rejected: return "已驳回"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

#Preview {
    OperationApprovalView()
        .environmentObject(UserState())
}
