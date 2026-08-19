import Foundation

struct Package {
    let id: UUID?
    let name: String
    let description: String?
    let category: String
    let price: Double
    let durationMinutes: Int
    let imageUrl: String?
    let trainingMaterials: [String]?
    
    var categoryColor: Color {
        switch category {
        case "skin": return .green
        case "body": return .blue
        case "face": return .pink
        case "hair": return .purple
        default: return .gray
        }
    }
    
    var categoryDisplay: String {
        switch category {
        case "skin": return "皮肤管理"
        case "body": return "身体护理"
        case "face": return "面部美容"
        case "hair": return "头发护理"
        default: return category
        }
    }
    
    init(id: UUID? = nil, name: String, description: String? = nil,
         category: String, price: Double, durationMinutes: Int,
         imageUrl: String? = nil, trainingMaterials: [String]? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.price = price
        self.durationMinutes = durationMinutes
        self.imageUrl = imageUrl
        self.trainingMaterials = trainingMaterials
    }
    
    init?(json: [String: Any]) {
        guard let id = json["id"] as? UUID,
              let name = json["name"] as? String,
              let price = json["price"] as? Double else { return nil }
        
        self.id = id
        self.name = name
        self.description = json["description"] as? String
        self.category = json["category"] as? String ?? "other"
        self.durationMinutes = json["duration_minutes"] as? Int ?? 60
        self.imageUrl = json["image_url"] as? String
        self.trainingMaterials = (json["training_materials"] as? [[String: String]])?
            .compactMap { $0["path"] }
    }
}