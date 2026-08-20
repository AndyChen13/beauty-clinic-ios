// Models/Customer.swift
import Foundation

struct Customer: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let phone: String
    let name: String
    let gender: String?
    let birthdate: Date?
    let medicalHistory: String?
    let preferences: [String: String]?
    let photoUrl: String?
    let associatedStoreId: UUID?
    let createdBy: UUID?
    let lastVisit: Date?
    let outstandingAmount: Double?
    let conversionProbability: Int?
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
        case outstandingAmount = "outstanding_amount"
        case conversionProbability = "conversion_probability"
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
        guard let birthdate = birthdate else { return nil }
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
        birthdate: Date? = nil,
        medicalHistory: String? = nil,
        preferences: [String: String]? = nil,
        photoUrl: String? = nil,
        associatedStoreId: UUID? = nil,
        createdBy: UUID? = nil,
        lastVisit: Date? = nil,
        outstandingAmount: Double? = nil,
        conversionProbability: Int? = nil,
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
        self.outstandingAmount = outstandingAmount
        self.conversionProbability = conversionProbability
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CustomerInsert: Codable, Sendable {
    let phone: String
    let name: String
    let gender: String?
    let birthdate: Date?
    let medicalHistory: String?
    let preferences: [String: String]?
    let associatedStoreId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case phone, name, gender, birthdate
        case medicalHistory = "medical_history"
        case preferences
        case associatedStoreId = "associated_store_id"
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
        case .before: return "治疗前"
        case .after: return "治疗后"
        case .progress: return "进度照"
        }
    }
}
