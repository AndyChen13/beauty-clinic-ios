import Foundation

// MARK: - Configuration
enum APIConfig {
    // Production: your Tencent Cloud server
    static let baseURL = "http://124.221.217.56"
    // Development: use your Mac's local IP for Simulator testing
    // Production: your Tencent Cloud server domain
    static let baseURL = "http://192.168.31.100:3000"
    
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

// MARK: - API Response
struct APIResponse<T: Codable>: Codable {
    let success: Bool?
    let error: String?
    let data: T?
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
    
    // MARK: - Generic Request
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
        
        // Add auth token
        if let token = APIConfig.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        // Check status code
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
        
        // Decode response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Try decoding as raw type first
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }
    }
    
    // MARK: - Convenience Methods
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
    
    var isAdmin: Bool { currentUser?.role == .admin }
    var storeId: String? { currentUser?.storeId?.uuidString }
    
    func sendCode(phone: String) async throws {
        struct SendCodeRequest: Codable {
            let phone: String
        }
        let _: [String: String] = try await APIClient.shared.post(
            path: "/api/auth/send-code",
            body: SendCodeRequest(phone: phone)
        )
    }
    
    func verifyCode(phone: String, code: String, name: String? = nil) async throws {
        struct VerifyRequest: Codable {
            let phone: String
            let code: String
            let name: String?
        }
        struct VerifyResponse: Codable {
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
        
        let response: VerifyResponse = try await APIClient.shared.post(
            path: "/api/auth/verify-code",
            body: VerifyRequest(phone: phone, code: code, name: name)
        )
        
        APIConfig.authToken = response.token
        
        // Convert to local User model
        let role = UserRole(rawValue: response.user.role) ?? .staff
        let storeUUID = response.user.storeId.flatMap { UUID(uuidString: $0) }
        let userUUID = UUID(uuidString: response.user.id)!
        
        currentUser = User(
            id: userUUID,
            email: nil,
            phone: response.user.phone,
            name: response.user.name,
            role: role,
            storeId: storeUUID,
            avatarUrl: response.user.avatarUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func loginWithPassword(phone: String, password: String) async throws {
        struct LoginRequest: Codable {
            let phone: String
            let password: String
        }
        struct LoginResponse: Codable {
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
        
        let response: LoginResponse = try await APIClient.shared.post(
            path: "/api/auth/login-password",
            body: LoginRequest(phone: phone, password: password)
        )
        
        APIConfig.authToken = response.token
        
        let role = UserRole(rawValue: response.user.role) ?? .staff
        let storeUUID = response.user.storeId.flatMap { UUID(uuidString: $0) }
        let userUUID = UUID(uuidString: response.user.id)!
        
        currentUser = User(
            id: userUUID,
            email: nil,
            phone: response.user.phone,
            name: response.user.name,
            role: role,
            storeId: storeUUID,
            avatarUrl: response.user.avatarUrl,
            createdAt: nil,
            updatedAt: nil
        )
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
