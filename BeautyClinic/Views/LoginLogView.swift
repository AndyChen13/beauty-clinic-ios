import SwiftUI

struct LoginLogView: View {
    @State private var logs: [LoginLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var hasMore = false
    @State private var totalLogs = 0
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -13, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    
    private let pageSize = 50
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return "\(formatter.string(from: startDate)) ~ \(formatter.string(from: endDate))"
    }
    
    /// 按账号聚合（以已加载的日志为准）
    private var accounts: [LoginAccountSummary] {
        let grouped = Dictionary(grouping: logs) { $0.userId }
        return grouped.compactMap { _, logs -> LoginAccountSummary? in
            guard let first = logs.first else { return nil }
            let sorted = logs.sorted { $0.loginAt > $1.loginAt }
            return LoginAccountSummary(
                userId: first.userId.uuidString,
                userName: first.userName,
                phone: first.phone,
                role: first.role,
                lastLoginAt: sorted.first?.loginAt ?? first.loginAt,
                count: logs.count,
                logs: sorted
            )
        }
        .sorted { $0.userName < $1.userName }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("时间范围")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(dateRangeText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("共 \(totalLogs) 条记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("涉及 \(accounts.count) 个账号")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if accounts.isEmpty && !isLoading {
                Section {
                    VStack(spacing: 8) {
                        Text("该时间段暂无登录记录")
                            .foregroundColor(.secondary)
                        Text("提示：登录日志从本功能上线后开始记录，其他账号需退出并重新登录后才会显示。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                }
            }
            
            ForEach(accounts) { account in
                NavigationLink {
                    UserLoginLogDetailView(
                        userId: account.userId,
                        userName: account.userName,
                        startDate: startDate,
                        endDate: endDate
                    )
                } label: {
                    AccountRow(summary: account)
                }
            }
            
            if hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onAppear {
                        loadMore()
                    }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("登录记录")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refresh()
        }
        .task {
            await refresh()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") {
                errorMessage = nil
                showError = false
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }
    
    private func refresh() async {
        currentPage = 1
        await loadLogs()
    }
    
    private func loadMore() {
        guard !isLoading, hasMore else { return }
        currentPage += 1
        Task {
            await loadLogs()
        }
    }
    
    private func loadLogs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await AdminService.shared.listLoginLogs(
                page: currentPage,
                limit: pageSize,
                startDate: startDate,
                endDate: endDate
            )
            print("[LoginLogView] loaded \(response.logs.count) logs, total=\(response.pagination.total)")
            await MainActor.run {
                if currentPage == 1 {
                    logs = response.logs
                } else {
                    logs.append(contentsOf: response.logs)
                }
                totalLogs = response.pagination.total
                totalPages = response.pagination.totalPages
                hasMore = currentPage < totalPages
            }
        } catch {
            print("[LoginLogView] error: \(error)")
            await MainActor.run {
                errorMessage = "加载失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 账号聚合模型

struct LoginAccountSummary: Identifiable {
    var id: String { userId }
    let userId: String
    let userName: String
    let phone: String?
    let role: String?
    let lastLoginAt: Date
    let count: Int
    let logs: [LoginLog]
    
    var roleDisplay: String {
        switch role {
        case "super_admin": return "超级管理员"
        case "staff": return "员工"
        default: return role ?? "未知"
        }
    }
}

// MARK: - 账号列表行

struct AccountRow: View {
    let summary: LoginAccountSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.userName)
                    .font(.headline)
                Spacer()
                Text(summary.roleDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                Label(summary.phone ?? "无手机号", systemImage: "phone.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("共 \(summary.count) 次", systemImage: "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Label(summary.lastLoginAt.formatted(date: .numeric, time: .standard), systemImage: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 账号详情（按时间倒序显示该账号所有登录）

struct UserLoginLogDetailView: View {
    let userId: String
    let userName: String
    let startDate: Date
    let endDate: Date
    
    @State private var logs: [LoginLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        List {
            if logs.isEmpty && !isLoading {
                Section {
                    Text("该时间段暂无记录")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            
            ForEach(logs) { log in
                LoginLogRow(log: log)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(userName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadLogs()
        }
        .task {
            await loadLogs()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") {
                errorMessage = nil
                showError = false
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }
    
    private func loadLogs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await AdminService.shared.listLoginLogs(
                page: 1,
                limit: 100,
                userId: userId,
                startDate: startDate,
                endDate: endDate
            )
            await MainActor.run {
                logs = response.logs.sorted { $0.loginAt > $1.loginAt }
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 单条登录记录行

struct LoginLogRow: View {
    let log: LoginLog
    
    private var statusColor: Color {
        log.status == "success" ? .green : .red
    }
    
    private var roleDisplay: String {
        switch log.role {
        case "super_admin": return "超级管理员"
        case "staff": return "员工"
        default: return log.role
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.userName)
                    .font(.headline)
                Spacer()
                Text(log.status == "success" ? "成功" : "失败")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                Label(log.phone ?? "无手机号", systemImage: "phone.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(roleDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                if let ip = log.ipAddress {
                    Label(ip, systemImage: "network")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Label(log.loginAt.formatted(date: .numeric, time: .standard), systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
