// Models/ServicePackage.swift
import Foundation
import SwiftUI

struct ServicePackage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let category: PackageCategory
    let price: Double
    let durationMinutes: Int
    let totalSessions: Int
    let imageUrl: String?
    let trainingMaterials: [String]?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, price
        case durationMinutes = "duration_minutes"
        case totalSessions = "total_sessions"
        case imageUrl = "image_url"
        case trainingMaterials = "training_materials"
        case isActive = "is_active"
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
    case training = "training"
    
    var displayName: String {
        switch self {
        case .skin: return "皮肤管理"
        case .body: return "身体护理"
        case .face: return "面部美容"
        case .hair: return "头发护理"
        case .other: return "其他"
        case .training: return "培训PPT"
        }
    }
    
    var color: Color {
        switch self {
        case .skin: return .green
        case .body: return .blue
        case .face: return .pink
        case .hair: return .purple
        case .other: return .gray
        case .training: return .orange
        }
    }
}

struct ServicePackageInsert: Codable, Sendable {
    let name: String
    let description: String?
    let category: PackageCategory
    let price: Double
    let durationMinutes: Int
    let totalSessions: Int
    let imageUrl: String?
    let trainingMaterials: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name, description, category, price
        case durationMinutes = "duration_minutes"
        case totalSessions = "total_sessions"
        case imageUrl = "image_url"
        case trainingMaterials = "training_materials"
    }
}

struct TrainingMaterial: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let packageId: UUID?
    let title: String
    let version: String
    let fileUrl: String
    let fileType: FileType
    let description: String?
    let uploadedBy: UUID?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case packageId = "package_id"
        case title, version
        case fileUrl = "file_url"
        case fileType = "file_type"
        case description
        case uploadedBy = "uploaded_by"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum FileType: String, Codable, Sendable, CaseIterable {
    case pdf = "pdf"
    case ppt = "ppt"
    case pptx = "pptx"
    case video = "video"
    case image = "image"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .ppt: return "PPT"
        case .pptx: return "PPTX"
        case .video: return "视频"
        case .image: return "图片"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.text"
        case .ppt, .pptx: return "play.rectangle"
        case .video: return "video.fill"
        case .image: return "photo"
        }
    }
}
