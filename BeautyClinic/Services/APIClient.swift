import Foundation

// MARK: - Configuration
enum APIConfig {
    // 使用 HTTPS 域名连接服务器（ATS 合规，可上线）
    static let baseURL = "https://andychenpersonal.com"
    
    static var authToken: String? {
        get { UserDefaults.standard.string(forKey: "api_auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "api_auth_token") }
    }
}

// MARK: - API Error
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case networkError(Error)
    case unauthorized
    case forbidden
    case pendingApproval(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .noData: return "没有返回数据"
        case .decodingError(let err): return "数据解析失败: \(err.localizedDescription)"
        case .serverError(let code, let msg):
            if let msg = msg, !msg.isEmpty { return msg }
            return "服务器错误 (\(code))"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        case .unauthorized: return "登录已过期，请重新登录"
        case .forbidden: return "没有权限执行此操作"
        case .pendingApproval(let msg): return msg
        }
    }
}

// MARK: - API Client
@MainActor
class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func dataRequest(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> Data {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = APIConfig.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            APIConfig.authToken = nil
            throw APIError.unauthorized
        case 403:
            // 登录未审批时后端返回 403 + error 字段
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
            if let msg = decoded?["error"], msg.contains("审批") {
                throw APIError.pendingApproval(msg)
            }
            throw APIError.forbidden
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        return data
    }

    func request<T: Codable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        let data = try await dataRequest(path: path, method: method, body: body)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            // 先尝试标准格式（无毫秒）
            if let date = formatter.date(from: dateString) {
                return date
            }
            // 再尝试带毫秒格式（后端 Prisma 默认）
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期: \(dateString)")
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(T.self, from: data)
    }
    
    func get<T: Codable>(path: String) async throws -> T {
        try await request(path: path, method: "GET")
    }
    
    func post<T: Codable>(path: String, body: Encodable? = nil) async throws -> T {
        try await request(path: path, method: "POST", body: body)
    }
    
    func put<T: Codable>(path: String, body: Encodable? = nil) async throws -> T {
        try await request(path: path, method: "PUT", body: body)
    }
    
    func delete<T: Codable>(path: String) async throws -> T {
        try await request(path: path, method: "DELETE")
    }
}

// MARK: - Auth Service
@MainActor
class AuthService {
    static let shared = AuthService()
    
    var currentUser: User? {
        didSet {
            NotificationCenter.default.post(name: .userDidChange, object: nil)
        }
    }
    
    var isAdmin: Bool { currentUser?.role == .superAdmin }
    var isSuperAdmin: Bool { currentUser?.role == .superAdmin }
    var storeId: String? { currentUser?.storeId?.uuidString }
    
    struct AuthResponse: Codable {
        let success: Bool
        let token: String
        let user: APUser
    }
    
    struct RegisterResponse: Codable {
        let success: Bool
        let message: String?
        let user: APUser
    }
    
    struct APUser: Codable {
        let id: String
        let phone: String?
        let name: String
        let role: String
        let status: String?
        let storeId: String?
        let avatarUrl: String?
    }
    
    struct RegisterRequest: Codable {
        let phone: String
        let password: String
        let name: String
    }
    
    struct LoginRequest: Codable {
        let phone: String
        let password: String
    }
    
    private func makeUser(from apUser: APUser) -> User {
        let role = UserRole(rawValue: apUser.role) ?? .staff
        let status = UserStatus(rawValue: apUser.status ?? "pending") ?? .pending
        let storeUUID = apUser.storeId.flatMap { UUID(uuidString: $0) }
        let userUUID = UUID(uuidString: apUser.id)!
        
        return User(
            id: userUUID,
            email: nil,
            phone: apUser.phone,
            name: apUser.name,
            role: role,
            status: status,
            storeId: storeUUID,
            avatarUrl: apUser.avatarUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func register(phone: String, password: String, name: String) async throws -> String {
        let response: RegisterResponse = try await APIClient.shared.post(
            path: "/api/auth/register",
            body: RegisterRequest(phone: phone, password: password, name: name)
        )
        return response.message ?? "注册成功，请等待超级管理员审批"
    }
    
    func login(phone: String, password: String) async throws {
        let response: AuthResponse = try await APIClient.shared.post(
            path: "/api/auth/login",
            body: LoginRequest(phone: phone, password: password)
        )
        APIConfig.authToken = response.token
        currentUser = makeUser(from: response.user)
    }
    
    func loadUser() async throws {
        struct MeResponse: Codable {
            let id: String
            let phone: String?
            let email: String?
            let name: String
            let role: String
            let status: String?
            let storeId: String?
            let avatarUrl: String?
        }
        
        let response: MeResponse = try await APIClient.shared.get(path: "/api/auth/me")
        
        let role = UserRole(rawValue: response.role) ?? .staff
        let status = UserStatus(rawValue: response.status ?? "pending") ?? .pending
        let storeUUID = response.storeId.flatMap { UUID(uuidString: $0) }
        let userUUID = UUID(uuidString: response.id)!
        
        currentUser = User(
            id: userUUID,
            email: response.email,
            phone: response.phone,
            name: response.name,
            role: role,
            status: status,
            storeId: storeUUID,
            avatarUrl: response.avatarUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func signOut() {
        APIConfig.authToken = nil
        currentUser = nil
    }
}

// MARK: - Admin Service
@MainActor
class AdminService {
    static let shared = AdminService()
    
    struct PendingUsersResponse: Codable {
        let success: Bool
        let users: [APPendingUser]
    }
    
    struct APPendingUser: Codable {
        let id: String
        let phone: String?
        let name: String
        let role: String?
        let status: String?
        let createdAt: String?
        let storeId: String?
    }
    
    struct ApprovalResponse: Codable {
        let success: Bool
        let user: AuthService.APUser
    }
    
    func listPendingUsers() async throws -> [User] {
        let response: PendingUsersResponse = try await APIClient.shared.get(path: "/api/users/pending")
        return response.users.map { u in
            User(
                id: UUID(uuidString: u.id)!,
                email: nil,
                phone: u.phone,
                name: u.name,
                role: UserRole(rawValue: u.role ?? "staff") ?? .staff,
                status: UserStatus(rawValue: u.status ?? "pending") ?? .pending,
                storeId: u.storeId.flatMap { UUID(uuidString: $0) },
                avatarUrl: nil,
                createdAt: ISO8601DateFormatter().date(from: u.createdAt ?? ""),
                updatedAt: nil
            )
        }
    }
    
    func approveUser(id: UUID) async throws {
        let _: ApprovalResponse = try await APIClient.shared.post(path: "/api/users/pending/\(id.uuidString)/approve")
    }
    
    func rejectUser(id: UUID) async throws {
        let _: ApprovalResponse = try await APIClient.shared.post(path: "/api/users/pending/\(id.uuidString)/reject")
    }
    
    func listLoginLogs(
        page: Int = 1,
        limit: Int = 50,
        userId: String? = nil,
        phone: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> LoginLogListResponse {
        var components = URLComponents(string: "/api/login-logs")!
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "userId", value: userId))
        }
        if let phone = phone {
            queryItems.append(URLQueryItem(name: "phone", value: phone))
        }
        // 用 UTC 完整时间串传给后端，避免 +08:00 里的 '+' 被 URL 解析成空格导致 Invalid Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
        }
        components.queryItems = queryItems
        let path = components.url?.absoluteString ?? "/api/login-logs"
        print("[AdminService.listLoginLogs] request: \(path)")
        let response: LoginLogListResponse = try await APIClient.shared.get(path: path)
        print("[AdminService.listLoginLogs] received \(response.logs.count) logs")
        return response
    }

    struct OperationApprovalListResponse: Codable {
        let success: Bool
        let approvals: [OperationApproval]
    }

    struct OperationApprovalActionRequest: Codable {
        let notes: String?
    }

    func listAllApprovals() async throws -> [OperationApproval] {
        let response: OperationApprovalListResponse = try await APIClient.shared.get(path: "/api/operation-approvals")
        return response.approvals
    }

    func listMyApprovals() async throws -> [OperationApproval] {
        let response: OperationApprovalListResponse = try await APIClient.shared.get(path: "/api/operation-approvals/mine")
        return response.approvals
    }

    func approveOperation(id: String, notes: String? = nil) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await APIClient.shared.post(
            path: "/api/operation-approvals/\(id)/approve",
            body: OperationApprovalActionRequest(notes: notes)
        )
    }

    func rejectOperation(id: String, notes: String? = nil) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await APIClient.shared.post(
            path: "/api/operation-approvals/\(id)/reject",
            body: OperationApprovalActionRequest(notes: notes)
        )
    }

    struct OperationApprovalCreateRequest: Codable {
        let operationType: String
        let targetType: String
        let targetId: String
        let payload: [String: JSONValue]?
    }

    struct OperationApprovalCreateResponse: Codable {
        let success: Bool
        let approval: OperationApproval
    }

    func createOperationApproval(
        operationType: String,
        targetType: String,
        targetId: UUID,
        payload: [String: JSONValue]? = nil
    ) async throws -> OperationApproval {
        let request = OperationApprovalCreateRequest(
            operationType: operationType,
            targetType: targetType,
            targetId: targetId.uuidString,
            payload: payload
        )
        let response: OperationApprovalCreateResponse = try await APIClient.shared.post(
            path: "/api/operation-approvals",
            body: request
        )
        return response.approval
    }
}

extension Notification.Name {
    static let userDidChange = Notification.Name("userDidChange")
}
