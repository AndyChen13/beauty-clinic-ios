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
    let amountReceived: Double?
    let storeRebateAmount: Double?
    let outstandingAmount: Double?
    let totalSessions: Int
    let completedSessions: Int
    let transactionDate: Date
    let firstDeliveryDate: Date?
    let estimatedCompletionDate: Date?
    let status: TransactionStatus
    let notes: String?
    let modifiedAt: Date?
    let modifiedBy: String?
    let modifiedByName: String?
    var auditLogs: [TransactionAuditLog]?
    let createdAt: Date?
    let updatedAt: Date?
    let branch: TransactionBranch
    
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
        case amountReceived = "amount_received"
        case storeRebateAmount = "store_rebate_amount"
        case outstandingAmount = "outstanding_amount"
        case branch
        case totalSessions = "total_sessions"
        case completedSessions = "completed_sessions"
        case transactionDate = "transaction_date"
        case firstDeliveryDate = "first_delivery_date"
        case estimatedCompletionDate = "estimated_completion_date"
        case status, notes
        case modifiedAt = "modified_at"
        case modifiedBy = "modified_by"
        case modifiedByName = "modified_by_name"
        case auditLogs = "audit_logs"
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

enum TransactionBranch: String, Codable, Sendable, CaseIterable {
    case photoElectric = "光电"
    case medicalBeauty = "医美"
    
    var displayName: String {
        switch self {
        case .photoElectric: return "光电"
        case .medicalBeauty: return "医美"
        }
    }
    
    var color: Color {
        switch self {
        case .photoElectric: return Color(hex: "5FB3A6")
        case .medicalBeauty: return Color(hex: "C9A24B")
        }
    }
}

enum TransactionStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case refunded = "refunded"
    case paid = "paid"
    
    var displayName: String {
        switch self {
        case .pending: return "待处理"
        case .confirmed: return "已确认"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .refunded: return "已退款"
        case .paid: return "已收款"
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
        case .paid: return .green
        }
    }
}

struct TransactionInsert: Codable, Sendable {
    let customerId: UUID
    let storeId: UUID
    let packageId: UUID?
    let staffUserId: UUID?
    let amount: Double
    let amountReceived: Double?
    let storeRebateAmount: Double?
    let outstandingAmount: Double?
    let branch: TransactionBranch
    let totalSessions: Int
    let transactionDate: Date
    let estimatedCompletionDate: Date?
    let status: TransactionStatus
    let notes: String?
    
    init(customerId: UUID, storeId: UUID, packageId: UUID?, staffUserId: UUID?, amount: Double, amountReceived: Double?, storeRebateAmount: Double? = nil, outstandingAmount: Double?, branch: TransactionBranch = .photoElectric, totalSessions: Int, transactionDate: Date, estimatedCompletionDate: Date?, status: TransactionStatus, notes: String?) {
        self.customerId = customerId
        self.storeId = storeId
        self.packageId = packageId
        self.staffUserId = staffUserId
        self.amount = amount
        self.amountReceived = amountReceived
        self.storeRebateAmount = storeRebateAmount
        self.outstandingAmount = outstandingAmount
        self.branch = branch
        self.totalSessions = totalSessions
        self.transactionDate = transactionDate
        self.estimatedCompletionDate = estimatedCompletionDate
        self.status = status
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case storeId = "store_id"
        case packageId = "package_id"
        case staffUserId = "staff_user_id"
        case amount
        case amountReceived = "amount_received"
        case storeRebateAmount = "store_rebate_amount"
        case outstandingAmount = "outstanding_amount"
        case branch
        case totalSessions = "total_sessions"
        case transactionDate = "transaction_date"
        case estimatedCompletionDate = "estimated_completion_date"
        case status, notes
    }
}

struct TransactionUpdate: Codable, Sendable {
    let amount: Double?
    let amountReceived: Double?
    let storeRebateAmount: Double?
    let branch: TransactionBranch?
    let totalSessions: Int?
    let notes: String?
    
    init(amount: Double? = nil, amountReceived: Double? = nil, storeRebateAmount: Double? = nil, branch: TransactionBranch? = nil, totalSessions: Int? = nil, notes: String? = nil) {
        self.amount = amount
        self.amountReceived = amountReceived
        self.storeRebateAmount = storeRebateAmount
        self.branch = branch
        self.totalSessions = totalSessions
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case amount
        case amountReceived = "amount_received"
        case storeRebateAmount = "store_rebate_amount"
        case branch
        case totalSessions = "total_sessions"
        case notes
    }
}

struct TransactionAuditLog: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let transactionId: UUID
    let field: String
    let oldValue: String?
    let newValue: String?
    let editedBy: String?
    let editedByName: String?
    let editedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case field
        case oldValue = "old_value"
        case newValue = "new_value"
        case editedBy = "edited_by"
        case editedByName = "edited_by_name"
        case editedAt = "edited_at"
    }
    
    var fieldDisplayName: String {
        switch field {
        case "amount": return "成交金额"
        case "amountReceived": return "已收金额"
        case "storeRebateAmount": return "门店返利金额"
        case "branch": return "成交归属"
        case "totalSessions": return "应交付次数"
        case "notes": return "备注"
        default: return field
        }
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
