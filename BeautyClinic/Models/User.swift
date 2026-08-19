//  Models/User.swift
//  BeautyClinic
//

import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let phone: String
    let name: String
    let role: UserRole
    let storeId: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, phone, name, role
        case storeId = "store_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
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
