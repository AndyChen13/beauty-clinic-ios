import SwiftUI

// MARK: - User Service
@MainActor
class UserService {
    static let shared = UserService()
    
    struct UserResponse: Codable {
        let id: String
        let email: String?
        let phone: String?
        let name: String
        let role: String
        let status: String?
        let storeId: String?
        let avatarUrl: String?
        let createdAt: String?
        let updatedAt: String?
        let store: StoreInfo?
        
        struct StoreInfo: Codable {
            let id: String
            let name: String
        }
    }
    
    private func parseISO8601Date(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    private func mapToUser(_ r: UserResponse) -> User {
        User(
            id: UUID(uuidString: r.id)!,
            email: r.email,
            phone: r.phone,
            name: r.name,
            role: UserRole(rawValue: r.role) ?? .staff,
            status: UserStatus(rawValue: r.status ?? "approved") ?? .approved,
            storeId: r.storeId.flatMap { UUID(uuidString: $0) },
            avatarUrl: r.avatarUrl,
            createdAt: parseISO8601Date(r.createdAt),
            updatedAt: parseISO8601Date(r.updatedAt)
        )
    }
    
    func listUsers() async throws -> [User] {
        let responses: [UserResponse] = try await APIClient.shared.get(path: "/api/users")
        return responses.map(mapToUser)
    }
    
    func createUser(phone: String, name: String, role: UserRole, password: String) async throws -> User {
        struct CreateBody: Codable {
            let phone: String
            let name: String
            let role: String
            let password: String
        }
        let body = CreateBody(phone: phone, name: name, role: role.rawValue, password: password)
        let r: UserResponse = try await APIClient.shared.post(path: "/api/users", body: body)
        return mapToUser(r)
    }
    
    func changeUserRole(userId: UUID, newRole: UserRole) async throws -> User {
        struct RoleBody: Codable {
            let role: String
        }
        let body = RoleBody(role: newRole.rawValue)
        let r: UserResponse = try await APIClient.shared.put(
            path: "/api/users/\(userId.uuidString)/role",
            body: body
        )
        return mapToUser(r)
    }
    
    func deleteUser(userId: UUID) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
        }
        let _: DeleteResponse = try await APIClient.shared.delete(path: "/api/users/\(userId.uuidString)")
    }
}

// MARK: - User Management View
struct UserManagementView: View {
    @EnvironmentObject var userState: UserState
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateUser = false
    @State private var showingRoleChangeAlert: (user: User, newRole: UserRole)?
    @State private var showingDeleteAlert: User?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task { await loadUsers() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无用户")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(users) { user in
                            UserRow(
                                user: user,
                                currentUser: userState.currentUser,
                                onRoleChange: { newRole in
                                    showingRoleChangeAlert = (user, newRole)
                                },
                                onDelete: {
                                    showingDeleteAlert = user
                                }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("用户管理")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateUser = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadUsers()
            }
            .task {
                await loadUsers()
            }
            .sheet(isPresented: $showingCreateUser) {
                CreateUserSheet { phone, name, role, password in
                    await createUser(phone: phone, name: name, role: role, password: password)
                }
            }
            .alert("确认提升权限", isPresented: Binding(
                get: { showingRoleChangeAlert != nil },
                set: { if !$0 { showingRoleChangeAlert = nil } }
            )) {
                Button("取消", role: .cancel) {
                    showingRoleChangeAlert = nil
                }
                Button("确认") {
                    if let info = showingRoleChangeAlert {
                        Task {
                            await changeRole(userId: info.user.id, newRole: info.newRole)
                        }
                    }
                }
            } message: {
                if let info = showingRoleChangeAlert, info.newRole == .superAdmin {
                    Text("确定要赋予 \(info.user.name) 最高权限吗？\n他将拥有与您相同的所有权限。")
                } else if let info = showingRoleChangeAlert {
                    Text("确定要将 \(info.user.name) 的角色更改为 \(info.newRole.displayName) 吗？")
                }
            }
            .alert("确认删除", isPresented: Binding(
                get: { showingDeleteAlert != nil },
                set: { if !$0 { showingDeleteAlert = nil } }
            )) {
                Button("取消", role: .cancel) {
                    showingDeleteAlert = nil
                }
                Button("删除", role: .destructive) {
                    if let user = showingDeleteAlert {
                        Task {
                            await deleteUser(user)
                        }
                    }
                }
            } message: {
                if let user = showingDeleteAlert {
                    Text("确定要删除用户 \(user.name) 吗？\n此操作不可撤销。")
                }
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await UserService.shared.listUsers()
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func createUser(phone: String, name: String, role: UserRole, password: String) async {
        do {
            let newUser = try await UserService.shared.createUser(
                phone: phone,
                name: name,
                role: role,
                password: password
            )
            users.insert(newUser, at: 0)
            showingCreateUser = false
        } catch {
            errorMessage = "创建失败: \(error.localizedDescription)"
        }
    }
    
    private func changeRole(userId: UUID, newRole: UserRole) async {
        do {
            let updatedUser = try await UserService.shared.changeUserRole(
                userId: userId,
                newRole: newRole
            )
            if let index = users.firstIndex(where: { $0.id == userId }) {
                users[index] = updatedUser
            }
            showingRoleChangeAlert = nil
        } catch {
            errorMessage = "修改失败: \(error.localizedDescription)"
        }
    }
    
    private func deleteUser(_ user: User) async {
        do {
            try await UserService.shared.deleteUser(userId: user.id)
            users.removeAll { $0.id == user.id }
            showingDeleteAlert = nil
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - User Row
struct UserRow: View {
    let user: User
    let currentUser: User?
    let onRoleChange: (UserRole) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name)
                        .font(.headline)
                    if user.isSuperAdmin {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                Text(user.phone ?? "无手机号")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if currentUser?.isSuperAdmin == true && user.id != currentUser?.id {
                Menu {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        Button {
                            onRoleChange(role)
                        } label: {
                            HStack {
                                Text(role.displayName)
                                if user.role == role {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除用户", systemImage: "trash")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(user.role.displayName)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(user.isSuperAdmin ? .yellow : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
                }
            } else {
                Text(user.role.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create User Sheet
struct CreateUserSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var phone = ""
    @State private var name = ""
    @State private var selectedRole: UserRole = .staff
    @State private var password = ""
    
    let onCreate: (String, String, UserRole, String) async -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("手机号", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("姓名", text: $name)
                    SecureField("密码", text: $password)
                }
                
                Section("权限设置") {
                    Picker("角色", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("新建用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        Task {
                            await onCreate(phone, name, selectedRole, password)
                            dismiss()
                        }
                    }
                    .disabled(phone.isEmpty || name.isEmpty || password.isEmpty)
                }
            }
        }
    }
}
