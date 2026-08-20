// Models/ServiceRecord.swift
import Foundation

struct ServiceRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let customerId: UUID
    let transactionId: UUID?
    let serviceDate: Date
    let operatorId: UUID?
    let operatorName: String?
    let operatorPhone: String?
    let bodyPart: String?
    let photos: [String]?
    let customerFeedback: String?
    let extraPayment: Double
    let extraPaymentNote: String?
    let sessionsUsed: Int
    let remainingSessions: Int?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case transactionId = "transaction_id"
        case serviceDate = "service_date"
        case operatorId = "operator_id"
        case operatorName = "operator_name"
        case operatorPhone = "operator_phone"
        case bodyPart = "body_part"
        case photos
        case customerFeedback = "customer_feedback"
        case extraPayment = "extra_payment"
        case extraPaymentNote = "extra_payment_note"
        case sessionsUsed = "sessions_used"
        case remainingSessions = "remaining_sessions"
        case createdAt = "created_at"
    }
}

struct ServiceRecordInsert: Codable, Sendable {
    let customerId: UUID
    let transactionId: UUID?
    let serviceDate: Date
    let operatorId: UUID?
    let operatorName: String?
    let operatorPhone: String?
    let bodyPart: String?
    let photos: [String]?
    let customerFeedback: String?
    let extraPayment: Double
    let extraPaymentNote: String?
    let sessionsUsed: Int
    let remainingSessions: Int?
    
    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case transactionId = "transaction_id"
        case serviceDate = "service_date"
        case operatorId = "operator_id"
        case operatorName = "operator_name"
        case operatorPhone = "operator_phone"
        case bodyPart = "body_part"
        case photos
        case customerFeedback = "customer_feedback"
        case extraPayment = "extra_payment"
        case extraPaymentNote = "extra_payment_note"
        case sessionsUsed = "sessions_used"
        case remainingSessions = "remaining_sessions"
    }
}
