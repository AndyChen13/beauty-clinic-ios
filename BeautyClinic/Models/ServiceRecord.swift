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
    let serviceDetails: String?
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
        case serviceDetails = "service_details"
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
    let serviceDetails: String?
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
        case serviceDetails = "service_details"
        case photos
        case customerFeedback = "customer_feedback"
        case extraPayment = "extra_payment"
        case extraPaymentNote = "extra_payment_note"
        case sessionsUsed = "sessions_used"
        case remainingSessions = "remaining_sessions"
    }
}

struct ServiceRecordUpdate: Codable, Sendable {
    let transactionId: UUID?
    let serviceDate: Date
    let operatorName: String?
    let operatorPhone: String?
    let bodyPart: String?
    let serviceDetails: String?
    let photos: [String]
    let customerFeedback: String?
    let extraPayment: Double
    let extraPaymentNote: String?
    let sessionsUsed: Int
    let remainingSessions: Int?
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case serviceDate = "service_date"
        case operatorName = "operator_name"
        case operatorPhone = "operator_phone"
        case bodyPart = "body_part"
        case serviceDetails = "service_details"
        case photos
        case customerFeedback = "customer_feedback"
        case extraPayment = "extra_payment"
        case extraPaymentNote = "extra_payment_note"
        case sessionsUsed = "sessions_used"
        case remainingSessions = "remaining_sessions"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode transactionId when present to avoid accidental disconnect
        try container.encodeIfPresent(transactionId, forKey: .transactionId)
        try container.encode(serviceDate, forKey: .serviceDate)
        // Encode optional strings as explicit null so the backend clears them
        try container.encode(operatorName, forKey: .operatorName)
        try container.encode(operatorPhone, forKey: .operatorPhone)
        try container.encode(bodyPart, forKey: .bodyPart)
        try container.encode(serviceDetails, forKey: .serviceDetails)
        try container.encode(photos, forKey: .photos)
        try container.encode(customerFeedback, forKey: .customerFeedback)
        try container.encode(extraPayment, forKey: .extraPayment)
        try container.encode(extraPaymentNote, forKey: .extraPaymentNote)
        try container.encode(sessionsUsed, forKey: .sessionsUsed)
        try container.encodeIfPresent(remainingSessions, forKey: .remainingSessions)
    }
}
