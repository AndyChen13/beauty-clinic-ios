// Models/User.swift
import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let email: String?
    let phone: String?
    let name: String
    let role: UserRole
    let storeId: UUID?
    let avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, email, phone, name, role
        case storeId = "store_id"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isSuperAdmin: Bool { role == .superAdmin }
    var isAdmin: Bool { role == .admin || role == .superAdmin }
}

enum UserRole: String, Codable, Sendable, CaseIterable {
    case superAdmin = "super_admin"
    case admin = "admin"
    case storeUser = "store_user"
    case staff = "staff"
    
    var displayName: String {
        switch self {
        case .superAdmin: return "超级管理员"
        case .admin: return "管理员"
        case .storeUser: return "门店用户"
        case .staff: return "员工"
        }
    }
}

struct UserInsert: Codable, Sendable {
    let id: UUID?
    let email: String?
    let name: String
    let phone: String?
    let role: UserRole
    let storeId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, phone, role
        case storeId = "store_id"
    }
}
