//  Models/Customer.swift
//  BeautyClinic
//

import Foundation

struct Customer: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let phone: String
    let name: String
    let gender: String?
    let birthdate: Date?
    let medicalHistory: String?
    let preferences: [String: String]?
    let associatedStoreId: UUID?
    let lastVisit: Date?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, phone, name, gender, birthdate
        case medicalHistory = "medical_history"
        case preferences
        case associatedStoreId = "associated_store_id"
        case lastVisit = "last_visit"
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
}

// For creating new customers
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
