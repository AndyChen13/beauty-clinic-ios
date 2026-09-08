// Models/Customer.swift
import Foundation
import SwiftUI

enum CustomerTag: String, CaseIterable {
    case photoElectric = "光电"
    case medicalBeauty = "医美"
    
    var displayName: String {
        switch self {
        case .photoElectric: return "光 · 电"
        case .medicalBeauty: return "医 · 美"
        }
    }
    
    var color: Color {
        switch self {
        case .photoElectric: return .cyan
        case .medicalBeauty: return .purple
        }
    }
}

extension Customer {
    /// 客户可同时属于多个板块；未设置时默认「光 · 电」
    var branchTags: [CustomerTag] {
        guard let raw = preferences?["branch"], !raw.isEmpty else { return [.photoElectric] }
        return raw.split(separator: ",").compactMap { CustomerTag(rawValue: String($0)) }
    }
    
    var branchTagString: String {
        CustomerTag.allCases
            .filter { branchTags.contains($0) }
            .map { $0.rawValue }
            .joined(separator: ",")
    }
    
    var preferencesNotes: String {
        guard let prefs = preferences else { return "" }
        return prefs.filter { $0.key != "branch" }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}

struct Customer: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let phone: String
    let name: String
    let gender: String?
    let birthdate: String?
    let medicalHistory: String?
    let preferences: [String: String]?
    let photoUrl: String?
    let associatedStoreId: UUID?
    let createdBy: UUID?
    let lastVisit: Date?
    let firstTransactionDate: Date?
    let firstTransactionAmount: Double?
    let amountReceived: Double?
    let outstandingAmount: Double?
    let conversionProbability: Int?
    let remainingSessions: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, phone, name, gender, birthdate
        case medicalHistory = "medical_history"
        case preferences
        case photoUrl = "photo_url"
        case associatedStoreId = "associated_store_id"
        case createdBy = "created_by"
        case lastVisit = "last_visit"
        case firstTransactionDate = "first_transaction_date"
        case firstTransactionAmount = "first_transaction_amount"
        case amountReceived = "amount_received"
        case outstandingAmount = "outstanding_amount"
        case conversionProbability = "conversion_probability"
        case remainingSessions = "remaining_sessions"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var genderDisplay: String {
        switch gender {
        case "male": return "男"
        case "female": return "女"
        case "other": return "其他"
        default: return "未知"
        }
    }
    
    var age: Int? {
        guard let birthdateString = birthdate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthdate = formatter.date(from: birthdateString) else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthdate, to: Date())
        return components.year
    }
    
    var preferencesString: String {
        guard let prefs = preferences, !prefs.isEmpty else { return "无备注" }
        return prefs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
    
    init(
        id: UUID,
        phone: String,
        name: String,
        gender: String? = nil,
        birthdate: String? = nil,
        medicalHistory: String? = nil,
        preferences: [String: String]? = nil,
        photoUrl: String? = nil,
        associatedStoreId: UUID? = nil,
        createdBy: UUID? = nil,
        lastVisit: Date? = nil,
        firstTransactionDate: Date? = nil,
        firstTransactionAmount: Double? = nil,
        amountReceived: Double? = nil,
        outstandingAmount: Double? = nil,
        conversionProbability: Int? = nil,
        remainingSessions: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.phone = phone
        self.name = name
        self.gender = gender
        self.birthdate = birthdate
        self.medicalHistory = medicalHistory
        self.preferences = preferences
        self.photoUrl = photoUrl
        self.associatedStoreId = associatedStoreId
        self.createdBy = createdBy
        self.lastVisit = lastVisit
        self.firstTransactionDate = firstTransactionDate
        self.firstTransactionAmount = firstTransactionAmount
        self.amountReceived = amountReceived
        self.outstandingAmount = outstandingAmount
        self.conversionProbability = conversionProbability
        self.remainingSessions = remainingSessions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CustomerInsert: Codable, Sendable {
    let phone: String
    let name: String
    let gender: String?
    let birthdate: String?
    let medicalHistory: String?
    let preferences: [String: String]?
    let associatedStoreId: UUID?
    let photoUrl: String?
    let firstTransactionDate: Date?
    let firstTransactionAmount: Double?
    let amountReceived: Double?
    let outstandingAmount: Double?
    let conversionProbability: Int?
    let remainingSessions: Int?
    
    enum CodingKeys: String, CodingKey {
        case phone, name, gender, birthdate
        case medicalHistory = "medical_history"
        case preferences
        case associatedStoreId = "associated_store_id"
        case photoUrl = "photo_url"
        case firstTransactionDate = "first_transaction_date"
        case firstTransactionAmount = "first_transaction_amount"
        case amountReceived = "amount_received"
        case outstandingAmount = "outstanding_amount"
        case conversionProbability = "conversion_probability"
        case remainingSessions = "remaining_sessions"
    }
    
    init(
        phone: String,
        name: String,
        gender: String? = nil,
        birthdate: String? = nil,
        medicalHistory: String? = nil,
        preferences: [String: String]? = nil,
        associatedStoreId: UUID? = nil,
        photoUrl: String? = nil,
        firstTransactionDate: Date? = nil,
        firstTransactionAmount: Double? = nil,
        amountReceived: Double? = nil,
        outstandingAmount: Double? = nil,
        conversionProbability: Int? = nil,
        remainingSessions: Int? = nil
    ) {
        self.phone = phone
        self.name = name
        self.gender = gender
        self.birthdate = birthdate
        self.medicalHistory = medicalHistory
        self.preferences = preferences
        self.associatedStoreId = associatedStoreId
        self.photoUrl = photoUrl
        self.firstTransactionDate = firstTransactionDate
        self.firstTransactionAmount = firstTransactionAmount
        self.amountReceived = amountReceived
        self.outstandingAmount = outstandingAmount
        self.conversionProbability = conversionProbability
        self.remainingSessions = remainingSessions
    }
}

struct CustomerPhoto: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let customerId: UUID
    let photoUrl: String
    let photoType: PhotoType
    let notes: String?
    let uploadedBy: UUID?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case photoUrl = "photo_url"
        case photoType = "photo_type"
        case notes
        case uploadedBy = "uploaded_by"
        case createdAt = "created_at"
    }
}

enum PhotoType: String, Codable, Sendable, CaseIterable {
    case profile = "profile"
    case before = "before"
    case after = "after"
    case progress = "progress"
    
    var displayName: String {
        switch self {
        case .profile: return "头像"
        case .before: return "护理前"
        case .after: return "护理后"
        case .progress: return "进度照"
        }
    }
}
