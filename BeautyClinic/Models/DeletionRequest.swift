// Models/DeletionRequest.swift
import Foundation
import SwiftUI

struct DeletionRequest: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let requesterId: UUID
    let targetType: String
    let targetId: UUID
    let targetName: String?
    let reason: String?
    let status: RequestStatus
    let adminNotes: String?
    let processedBy: UUID?
    let processedAt: Date?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case targetName = "target_name"
        case reason
        case status
        case adminNotes = "admin_notes"
        case processedBy = "processed_by"
        case processedAt = "processed_at"
        case createdAt = "created_at"
    }
}

enum RequestStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "待审批"
        case .approved: return "已通过"
        case .rejected: return "已驳回"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

struct DeletionRequestInsert: Codable, Sendable {
    let requesterId: UUID
    let targetType: String
    let targetId: UUID
    let targetName: String?
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case requesterId = "requester_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case targetName = "target_name"
        case reason
    }
}
