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
    let icon: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, phone, status, icon
        case managerId = "manager_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var iconName: String {
        icon ?? "building.2.fill"
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
    let icon: String?
    
    enum CodingKeys: String, CodingKey {
        case name, address, phone, status, icon
        case managerId = "manager_id"
    }
}

let storeIconOptions = [
    ("building.2.fill", "默认门店"),
    ("storefront.fill", "街边店"),
    ("house.fill", "工作室"),
    ("cross.case.fill", "医疗美容"),
    ("heart.fill", "美容护理"),
    ("sparkles", "高端会所"),
    ("leaf.fill", "自然疗法"),
    ("wand.and.stars", "科技美容"),
]
