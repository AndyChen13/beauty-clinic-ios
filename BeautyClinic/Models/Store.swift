// Models/Store.swift
import Foundation
import SwiftUI

struct Store: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let address: String?
    let phone: String?
    let status: StoreStatus
    let managerId: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, phone, status
        case managerId = "manager_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum StoreStatus: String, Codable, Sendable, CaseIterable {
    case active = "active"
    case pending = "pending"
    case closed = "closed"
    
    var displayName: String {
        switch self {
        case .active: return "运营中"
        case .pending: return "筹备中"
        case .closed: return "已关闭"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .pending: return .orange
        case .closed: return .red
        }
    }
}

struct StoreInsert: Codable, Sendable {
    let name: String
    let address: String?
    let phone: String?
    let status: StoreStatus
    let managerId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case name, address, phone, status
        case managerId = "manager_id"
    }
}
