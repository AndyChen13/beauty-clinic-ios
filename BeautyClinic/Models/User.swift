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
    
    var isAdmin: Bool { role == .admin }
    var isManager: Bool { role == .manager }
}

enum UserRole: String, Codable, Sendable, CaseIterable {
    case admin = "admin"
    case manager = "manager"
    case staff = "staff"
    
    var displayName: String {
        switch self {
        case .admin: return "超级管理员"
        case .manager: return "门店经理"
        case .staff: return "普通员工"
        }
    }
}

struct UserInsert: Codable, Sendable {
    let id: UUID?
    let email: String?
    let name: String
    let role: UserRole
    let storeId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, role
        case storeId = "store_id"
    }
}
