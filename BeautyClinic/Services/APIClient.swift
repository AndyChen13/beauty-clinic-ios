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
    
    func request<T: Codable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
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
            throw APIError.forbidden
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
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
    
    var isAdmin: Bool { currentUser?.role == .admin || currentUser?.role == .superAdmin }
    var storeId: String? { currentUser?.storeId?.uuidString }
    
    struct AuthResponse: Codable {
        let success: Bool
        let token: String
        let user: APUser
    }
    
    struct APUser: Codable {
        let id: String
        let phone: String?
        let name: String
        let role: String
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
    
    private func saveUser(from apUser: APUser) {
        let role = UserRole(rawValue: apUser.role) ?? .staff
        let storeUUID = apUser.storeId.flatMap { UUID(uuidString: $0) }
        let userUUID = UUID(uuidString: apUser.id)!
        
        currentUser = User(
            id: userUUID,
            email: nil,
            phone: apUser.phone,
            name: apUser.name,
            role: role,
            storeId: storeUUID,
            avatarUrl: apUser.avatarUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func register(phone: String, password: String, name: String) async throws {
        let response: AuthResponse = try await APIClient.shared.post(
            path: "/api/auth/register",
            body: RegisterRequest(phone: phone, password: password, name: name)
        )
        APIConfig.authToken = response.token
        saveUser(from: response.user)
    }
    
    func login(phone: String, password: String) async throws {
        let response: AuthResponse = try await APIClient.shared.post(
            path: "/api/auth/login",
            body: LoginRequest(phone: phone, password: password)
        )
        APIConfig.authToken = response.token
        saveUser(from: response.user)
    }
    
    func loadUser() async throws {
        struct MeResponse: Codable {
            let id: String
            let phone: String?
            let email: String?
            let name: String
            let role: String
            let storeId: String?
            let avatarUrl: String?
        }
        
        let response: MeResponse = try await APIClient.shared.get(path: "/api/auth/me")
        
        let role = UserRole(rawValue: response.role) ?? .staff
        let storeUUID = response.storeId.flatMap { UUID(uuidString: $0) }
        let userUUID = UUID(uuidString: response.id)!
        
        currentUser = User(
            id: userUUID,
            email: response.email,
            phone: response.phone,
            name: response.name,
            role: role,
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

extension Notification.Name {
    static let userDidChange = Notification.Name("userDidChange")
}
