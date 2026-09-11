// Models/User.swift
import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let email: String?
    let phone: String?
    let name: String
    let role: UserRole
    var status: UserStatus
    let storeId: UUID?
    let avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, email, phone, name, role, status
        case storeId = "store_id"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isSuperAdmin: Bool { role == .superAdmin }
    var isAdmin: Bool { role == .superAdmin }
    var isApproved: Bool { status == .approved }
}

enum UserRole: String, Codable, Sendable, CaseIterable {
    case superAdmin = "super_admin"
    case staff = "staff"
    
    var displayName: String {
        switch self {
        case .superAdmin: return "超级管理员"
        case .staff: return "员工"
        }
    }
}

enum UserStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "待审批"
        case .approved: return "已通过"
        case .rejected: return "已拒绝"
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

struct UserStatusUpdate: Codable, Sendable {
    let status: UserStatus
}
