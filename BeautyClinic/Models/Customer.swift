import Foundation
import SwiftData

@Model
class Customer {
    var id: UUID?
    var phone: String
    var name: String
    var gender: String?
    var birthdate: Date?
    var medical_history: String?
    @Attribute(.externalStorage) var preferences: Data?
    
    init(phone: String, name: String, gender: String? = nil, 
         birthdate: Date? = nil, medical_history: String? = nil,
         preferences: [String: Any]? = nil) {
        self.id = UUID()
        self.phone = phone
        self.name = name
        self.gender = gender
        self.birthdate = birthdate
        self.medical_history = medical_history
        if let prefs = preferences {
            self.preferences = try? JSONSerialization.data(withJSONObject: prefs)
        }
    }
    
    // Computed properties for SwiftUI
    var preferencesString: String {
        guard let data = preferences,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        return json.map { "\($0): \($1)" }.joined(separator: "\n")
    }
    
    // Initializer for Supabase results
    convenience init?(json: [String: Any]) {
        guard let phone = json["phone"] as? String,
              let name = json["name"] as? String else { return nil }
        
        self.init(
            phone: phone,
            name: name,
            gender: json["gender"] as? String,
            birthdate: json["birthdate"] as? Date,
            medical_history: json["medical_history"] as? String,
            preferences: json["preferences"] as? [String: Any]
        )
    }
}