import Foundation

struct Transaction {
    let id: UUID?
    var customerId: UUID
    var storeId: UUID
    var packageId: UUID
    var staffUserId: UUID?
    
    var amount: Double
    var transactionDate: Date
    var scheduledAt: Date?
    var status: String
    var notes: String?
    
    // Computed properties for display
    var packageName: String { "医美套餐" }  // TODO: Load from packages table
    var customerName: String? { "客户姓名" } // TODO: Load from customers table
    
    init(id: UUID? = nil, customerId: UUID, storeId: UUID,
         packageId: UUID, staffUserId: UUID? = nil,
         amount: Double, transactionDate: Date, scheduledAt: Date? = nil,
         status: String = "pending", notes: String? = nil) {
        self.id = id
        self.customerId = customerId
        self.storeId = storeId
        self.packageId = packageId
        self.staffUserId = staffUserId
        self.amount = amount
        self.transactionDate = transactionDate
        self.scheduledAt = scheduledAt
        self.status = status
        self.notes = notes
    }
    
    var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "confirmed": return .blue
        case "completed": return .green
        case "cancelled": return .red
        case "refunded": return .gray
        default: return .secondary
        }
    }
    
    init?(json: [String: Any]) {
        guard let id = json["id"] as? UUID,
              let customerId = json["customer_id"] as? UUID,
              let storeId = json["store_id"] as? UUID,
              let amount = json["amount"] as? Double else { return nil }
        
        self.id = id
        self.customerId = customerId
        self.storeId = storeId
        self.packageId = json["package_id"] as? UUID ?? UUID()
        self.staffUserId = json["staff_user_id"] as? UUID
        
        self.amount = amount
        self.transactionDate = json["transaction_date"] as? Date ?? Date()
        self.scheduledAt = json["scheduled_at"] as? Date
        self.status = json["status"] as? String ?? "pending"
        self.notes = json["notes"] as? String
    }
}