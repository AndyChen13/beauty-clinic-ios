//  Models/Transaction.swift
//  BeautyClinic
//

import Foundation
import SwiftUI

struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let customerId: UUID
    let storeId: UUID
    let packageId: UUID
    let staffUserId: UUID?
    let amount: Double
    let transactionDate: Date
    let scheduledAt: Date?
    let status: TransactionStatus
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Joined fields (not in DB, populated via query)
    var customerName: String?
    var packageName: String?
    var storeName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case storeId = "store_id"
        case packageId = "package_id"
        case staffUserId = "staff_user_id"
        case amount
        case transactionDate = "transaction_date"
        case scheduledAt = "scheduled_at"
        case status, notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case customerName = "customer_name"
        case packageName = "package_name"
        case storeName = "store_name"
    }
}

enum TransactionStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
    case refunded = "refunded"
    
    var displayName: String {
        switch self {
        case .pending: return "待处理"
        case .confirmed: return "已确认"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .refunded: return "已退款"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .refunded: return .gray
        }
    }
}

struct TransactionInsert: Codable, Sendable {
    let customerId: UUID
    let storeId: UUID
    let packageId: UUID
    let staffUserId: UUID?
    let amount: Double
    let transactionDate: Date
    let scheduledAt: Date?
    let status: TransactionStatus
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case storeId = "store_id"
        case packageId = "package_id"
        case staffUserId = "staff_user_id"
        case amount
        case transactionDate = "transaction_date"
        case scheduledAt = "scheduled_at"
        case status, notes
    }
}
