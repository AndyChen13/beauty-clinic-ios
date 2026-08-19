//  Models/ServicePackage.swift
//  BeautyClinic
//

import Foundation
import SwiftUI

// Renamed from 'Package' to avoid conflict with Swift Package Manager
struct ServicePackage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let category: PackageCategory
    let price: Double
    let durationMinutes: Int
    let imageUrl: String?
    let trainingMaterials: [String]?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, price
        case durationMinutes = "duration_minutes"
        case imageUrl = "image_url"
        case trainingMaterials = "training_materials"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum PackageCategory: String, Codable, Sendable, CaseIterable {
    case skin = "skin"
    case body = "body"
    case face = "face"
    case hair = "hair"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .skin: return "皮肤管理"
        case .body: return "身体护理"
        case .face: return "面部美容"
        case .hair: return "头发护理"
        case .other: return "其他"
        }
    }
    
    var color: Color {
        switch self {
        case .skin: return .green
        case .body: return .blue
        case .face: return .pink
        case .hair: return .purple
        case .other: return .gray
        }
    }
}

struct ServicePackageInsert: Codable, Sendable {
    let name: String
    let description: String?
    let category: PackageCategory
    let price: Double
    let durationMinutes: Int
    let imageUrl: String?
    let trainingMaterials: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name, description, category, price
        case durationMinutes = "duration_minutes"
        case imageUrl = "image_url"
        case trainingMaterials = "training_materials"
    }
}
