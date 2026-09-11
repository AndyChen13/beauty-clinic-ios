import Foundation

struct LoginLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let userName: String
    let phone: String?
    let role: String
    let ipAddress: String?
    let userAgent: String?
    let status: String
    let loginAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userId, userName, phone, role, ipAddress, userAgent, status, loginAt
    }
}

struct LoginLogListResponse: Codable {
    let logs: [LoginLog]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
    }
}
