// Models/OperationApproval.swift
import Foundation

enum ApprovalStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

indirect enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if container.decodeNil() {
            self = .null
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let values): try container.encode(values)
        case .object(let object): try container.encode(object)
        }
    }
}

extension JSONValue: CustomStringConvertible {
    var description: String {
        switch self {
        case .string(let value): return value
        case .number(let value):
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            }
            return String(value)
        case .bool(let value): return value ? "是" : "否"
        case .null: return "-"
        case .array(let values): return "[\(values.map { $0.description }.joined(separator: ", "))]"
        case .object(let object):
            return object.map { "\($0.key): \($0.value.description)" }.joined(separator: "\n")
        }
    }
}

struct OperationApproval: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let operationType: String
    let targetType: String
    let targetId: String
    let payload: [String: JSONValue]?
    let requestedBy: String?
    let requestedByName: String?
    let status: ApprovalStatus
    let reviewedBy: String?
    let reviewedByName: String?
    let reviewedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
}

struct OperationApprovalListResponse: Codable {
    let success: Bool
    let approvals: [OperationApproval]
}

struct OperationApprovalActionRequest: Codable {
    let notes: String?
}
