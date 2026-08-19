// Models/Transaction.swift
import Foundation
import SwiftUI

struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let customerId: UUID
    let storeId: UUID
    let packageId: UUID
    let staffUserId: UUID?
    let amount: Double
    let totalSessions: Int
    let completedSessions: Int
    let transactionDate: Date
    let firstDeliveryDate: Date?
    let estimatedCompletionDate: Date?
    let status: TransactionStatus
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?
    
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
        case totalSessions = "total_sessions"
        case completedSessions = "completed_sessions"
        case transactionDate = "transaction_date"
        case firstDeliveryDate = "first_delivery_date"
        case estimatedCompletionDate = "estimated_completion_date"
        case status, notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case customerName = "customer_name"
        case packageName = "package_name"
        case storeName = "store_name"
    }
    
    var remainingSessions: Int {
        totalSessions - completedSessions
    }
    
    var progressPercentage: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(totalSessions)
    }
}

enum TransactionStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case refunded = "refunded"
    
    var displayName: String {
        switch self {
        case .pending: return "待处理"
        case .confirmed: return "已确认"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .refunded: return "已退款"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .blue
        case .inProgress: return .purple
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
    let totalSessions: Int
    let transactionDate: Date
    let estimatedCompletionDate: Date?
    let status: TransactionStatus
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case storeId = "store_id"
        case packageId = "package_id"
        case staffUserId = "staff_user_id"
        case amount
        case totalSessions = "total_sessions"
        case transactionDate = "transaction_date"
        case estimatedCompletionDate = "estimated_completion_date"
        case status, notes
    }
}

struct Delivery: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let transactionId: UUID
    let customerId: UUID
    let storeId: UUID
    let staffUserId: UUID?
    let sessionNumber: Int
    let deliveryDate: Date
    let notes: String?
    let photos: [String]?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case customerId = "customer_id"
        case storeId = "store_id"
        case staffUserId = "staff_user_id"
        case sessionNumber = "session_number"
        case deliveryDate = "delivery_date"
        case notes, photos
        case createdAt = "created_at"
    }
}

struct DeliveryInsert: Codable, Sendable {
    let transactionId: UUID
    let customerId: UUID
    let storeId: UUID
    let staffUserId: UUID?
    let sessionNumber: Int
    let notes: String?
    let photos: [String]?
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case customerId = "customer_id"
        case storeId = "store_id"
        case staffUserId = "staff_user_id"
        case sessionNumber = "session_number"
        case notes, photos
    }
}
