// Views/UserApprovalView.swift
import SwiftUI

struct UserApprovalView: View {
    @EnvironmentObject var userState: UserState
    @State private var pendingUsers: [User] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedUser: User?
    @State private var showActionSheet = false
    @State private var processingUserId: UUID?

    var body: some View {
        NavigationStack {
            List {
                if !pendingUsers.isEmpty {
                    Section("待审批注册申请") {
                        ForEach(pendingUsers) { user in
                            PendingUserRow(user: user, isProcessing: processingUserId == user.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedUser = user
                                    showActionSheet = true
                                }
                        }
                    }
                }

                if pendingUsers.isEmpty && !isLoading {
                    Section {
                        EmptyStateView(
                            icon: "person.badge.shield.checkmark.fill",
                            title: "暂无待审批用户",
                            subtitle: "新注册用户会显示在这里"
                        )
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("新注册审批")
            .refreshable { await loadPendingUsers() }
            .task { await loadPendingUsers() }
            .confirmationDialog("审批操作", isPresented: $showActionSheet, presenting: selectedUser) { user in
                Button("同意 \(user.name) 注册") {
                    approve(user: user)
                }
                Button("拒绝 \(user.name) 注册", role: .destructive) {
                    reject(user: user)
                }
                Button("取消", role: .cancel) { }
            } message: { user in
                Text("手机号：\(user.phone ?? "无")")
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func loadPendingUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let users = try await AdminService.shared.listPendingUsers()
            pendingUsers = users
        } catch {
            print("加载待审批用户失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func approve(user: User) {
        processingUserId = user.id
        Task {
            do {
                try await AdminService.shared.approveUser(id: user.id)
                await MainActor.run {
                    pendingUsers.removeAll { $0.id == user.id }
                    userState.pendingUserCount = max(0, userState.pendingUserCount - 1)
                }
            } catch {
                errorMessage = "审批失败: \(error.localizedDescription)"
                showError = true
            }
            processingUserId = nil
        }
    }

    private func reject(user: User) {
        processingUserId = user.id
        Task {
            do {
                try await AdminService.shared.rejectUser(id: user.id)
                await MainActor.run {
                    pendingUsers.removeAll { $0.id == user.id }
                    userState.pendingUserCount = max(0, userState.pendingUserCount - 1)
                }
            } catch {
                errorMessage = "拒绝失败: \(error.localizedDescription)"
                showError = true
            }
            processingUserId = nil
        }
    }
}

struct PendingUserRow: View {
    let user: User
    let isProcessing: Bool

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: user.name, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.subheadline.weight(.medium))
                Text(user.phone ?? "无手机号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let createdAt = user.createdAt {
                    Text(createdAt.formatted())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isProcessing {
                ProgressView()
            } else {
                Text("待审批")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UserApprovalView()
        .environmentObject(UserState())
}
