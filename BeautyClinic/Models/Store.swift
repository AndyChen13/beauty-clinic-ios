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
    let imageUrl: String?
    let notes: String?
    let introduction: String?
    let recommendedHotel: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    init(
        id: UUID,
        name: String,
        address: String? = nil,
        phone: String? = nil,
        status: StoreStatus,
        managerId: UUID? = nil,
        imageUrl: String? = nil,
        notes: String? = nil,
        introduction: String? = nil,
        recommendedHotel: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.status = status
        self.managerId = managerId
        self.imageUrl = imageUrl
        self.notes = notes
        self.introduction = introduction
        self.recommendedHotel = recommendedHotel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, phone, status, notes, introduction
        case managerId = "manager_id"
        case imageUrl = "image_url"
        case recommendedHotel = "recommended_hotel"
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
    let imageUrl: String?
    let notes: String?
    let introduction: String?
    let recommendedHotel: String?

    init(
        name: String,
        address: String? = nil,
        phone: String? = nil,
        status: StoreStatus,
        managerId: UUID? = nil,
        imageUrl: String? = nil,
        notes: String? = nil,
        introduction: String? = nil,
        recommendedHotel: String? = nil
    ) {
        self.name = name
        self.address = address
        self.phone = phone
        self.status = status
        self.managerId = managerId
        self.imageUrl = imageUrl
        self.notes = notes
        self.introduction = introduction
        self.recommendedHotel = recommendedHotel
    }

    enum CodingKeys: String, CodingKey {
        case name, address, phone, status, notes, introduction
        case managerId = "manager_id"
        case imageUrl = "image_url"
        case recommendedHotel = "recommended_hotel"
    }
}
