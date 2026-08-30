// Views/AdminApprovalView.swift
import SwiftUI

struct AdminApprovalView: View {
    @EnvironmentObject var userState: UserState
    @State private var requests: [DeletionRequest] = []
    @State private var isLoading = false
    @State private var showDetailSheet = false
    @State private var selectedRequest: DeletionRequest?
    @State private var adminNote = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var pendingRequests: [DeletionRequest] {
        requests.filter { $0.status == .pending }
    }
    
    var processedRequests: [DeletionRequest] {
        requests.filter { $0.status != .pending }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !pendingRequests.isEmpty {
                    Section("待审批 (\(pendingRequests.count))") {
                        ForEach(pendingRequests) { request in
                            RequestRow(request: request)
                                .onTapGesture {
                                    selectedRequest = request
                                    showDetailSheet = true
                                }
                        }
                    }
                }
                
                if !processedRequests.isEmpty {
                    Section("已处理") {
                        ForEach(processedRequests) { request in
                            RequestRow(request: request)
                        }
                    }
                }
                
                if requests.isEmpty && !isLoading {
                    Section {
                        EmptyStateView(
                            icon: "checkmark.shield",
                            title: "暂无删除申请",
                            subtitle: "所有删除申请都会显示在这里"
                        )
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("删除审批")
            .refreshable { await loadRequests() }
            .task { await loadRequests() }
            .sheet(isPresented: $showDetailSheet) {
                if let request = selectedRequest {
                    ApprovalDetailSheet(
                        request: request,
                        adminNote: $adminNote,
                        onApprove: { approveRequest(request) },
                        onReject: { rejectRequest(request) }
                    )
                }
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: [DeletionRequest] = try await APIClient.shared.get(path: "/api/deletion-requests")
            requests = result
        } catch {
            print("Error loading requests: \(error)")
        }
    }
    
    private func approveRequest(_ request: DeletionRequest) {
        Task {
            do {
                struct ApproveBody: Codable {
                    let adminNotes: String?
                }
                let _: EmptyResponse = try await APIClient.shared.put(
                    path: "/api/deletion-requests/\(request.id.uuidString)/approve",
                    body: ApproveBody(adminNotes: adminNote.isEmpty ? nil : adminNote)
                )
                
                adminNote = ""
                await loadRequests()
            } catch {
                errorMessage = "审批失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func rejectRequest(_ request: DeletionRequest) {
        Task {
            do {
                struct RejectBody: Codable {
                    let adminNotes: String?
                }
                let _: EmptyResponse = try await APIClient.shared.put(
                    path: "/api/deletion-requests/\(request.id.uuidString)/reject",
                    body: RejectBody(adminNotes: adminNote.isEmpty ? nil : adminNote)
                )
                
                adminNote = ""
                await loadRequests()
            } catch {
                errorMessage = "驳回失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct EmptyResponse: Codable {}

struct RequestRow: View {
    let request: DeletionRequest
    
    private var typeDisplay: String {
        switch request.targetType {
        case "customer": return "客户"
        case "store": return "门店"
        case "package": return "套餐"
        case "user": return "用户"
        default: return request.targetType
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(request.status.color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: statusIcon)
                        .font(.system(size: 14))
                        .foregroundColor(request.status.color)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(request.targetName ?? "未命名")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text(typeDisplay)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                    Text(request.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Text(request.status.displayName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(request.status.color.opacity(0.12))
                .foregroundColor(request.status.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch request.status {
        case .pending: return "clock"
        case .approved: return "checkmark"
        case .rejected: return "xmark"
        }
    }
}

struct ApprovalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let request: DeletionRequest
    @Binding var adminNote: String
    let onApprove: () -> Void
    let onReject: () -> Void
    
    private var typeDisplay: String {
        switch request.targetType {
        case "customer": return "客户"
        case "store": return "门店"
        case "package": return "套餐"
        case "user": return "用户"
        default: return request.targetType
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("申请信息") {
                    InfoRow(label: "类型", value: typeDisplay)
                    InfoRow(label: "名称", value: request.targetName ?? "未命名")
                    if let reason = request.reason, !reason.isEmpty {
                        InfoRow(label: "删除原因", value: reason)
                    }
                    InfoRow(label: "申请时间", value: request.createdAt?.formatted() ?? "未知")
                }
                
                Section("审批备注") {
                    TextEditor(text: $adminNote)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Button(role: .destructive) {
                        onApprove()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("同意删除")
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
}

#Preview {
    AdminApprovalView()
        .environmentObject(UserState())
}
