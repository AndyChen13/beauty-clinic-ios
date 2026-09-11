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

struct StoreRebatePeriod: Codable, Identifiable, Sendable {
    let id: String
    let storeId: String
    var startAt: Date
    var endAt: Date?
    var threshold1: Double
    var rebate1: Double
    var threshold2: Double
    var rebate2: Double
    var threshold3: Double
    var rebate3: Double
    var status: String
    var autoRebate: Double?
    var confirmedRebate: Double?
    var confirmedAt: Date?
    var confirmedById: String?
    var confirmedByName: String?
    let createdAt: Date
    let updatedAt: Date

    // 后端 GET /active 会额外返回 currentAmount 与 autoRebate（已映射到本字段）用于实时汇算
    var currentAmount: Double?

    // 后端接口统一返回 camelCase，请求时 StoreRebatePeriodInsert 走 snake_case
    enum CodingKeys: String, CodingKey {
        case id, storeId, startAt, endAt, threshold1, rebate1, threshold2, rebate2, threshold3, rebate3, status
        case autoRebate, confirmedRebate, confirmedAt, confirmedById, confirmedByName, createdAt, updatedAt
        case currentAmount
    }
}

struct StoreRebatePeriodInsert: Codable, Sendable {
    let startAt: Date
    let endAt: Date?
    let threshold1: Double
    let rebate1: Double
    let threshold2: Double
    let rebate2: Double
    let threshold3: Double
    let rebate3: Double

    enum CodingKeys: String, CodingKey {
        case startAt = "start_at"
        case endAt = "end_at"
        case threshold1 = "threshold_1"
        case rebate1 = "rebate_1"
        case threshold2 = "threshold_2"
        case rebate2 = "rebate_2"
        case threshold3 = "threshold_3"
        case rebate3 = "rebate_3"
    }
}
