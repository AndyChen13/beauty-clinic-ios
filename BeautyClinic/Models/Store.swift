import Foundation

struct Store {
    let id: UUID?
    let name: String
    let address: String?
    let phone: String?
    let status: String
    let managerUserId: UUID?
    
    var statusColor: Color {
        switch status {
        case "active": return .green
        case "pending": return .orange
        case "closed": return .red
        default: return .gray
        }
    }
    
    var statusDisplay: String {
        switch status {
        case "active": return "运营中"
        case "pending": return "筹备中"
        case "closed": return "已关闭"
        default: return status
        }
    }
    
    init(id: UUID? = nil, name: String, address: String? = nil,
         phone: String? = nil, status: String = "active",
         managerUserId: UUID? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.status = status
        self.managerUserId = managerUserId
    }
    
    init?(json: [String: Any]) {
        guard let id = json["id"] as? UUID,
              let name = json["name"] as? String else { return nil }
        
        self.id = id
        self.name = name
        self.address = json["address"] as? String
        self.phone = json["phone"] as? String
        self.status = json["status"] as? String ?? "active"
        self.managerUserId = json["manager_user_id"] as? UUID
    }
}