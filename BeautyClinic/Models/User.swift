// User.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import Foundation
import SwiftData

@Model
class User {
    var id: UUID?
    var phone: String
    var name: String
    var role: String // admin, manager, staff
    var storeId: UUID?
    
    init(id: UUID? = nil, phone: String, name: String,
         role: String = "staff", storeId: UUID? = nil) {
        self.id = id
        self.phone = phone
        self.name = name
        self.role = role
        self.storeId = storeId
    }
    
    convenience init?(json: [String: Any]) {
        guard let id = json["id"] as? UUID,
              let phone = json["phone"] as? String,
              let name = json["name"] as? String else { return nil }
        
        self.init(
            id: id,
            phone: phone,
            name: name,
            role: json["role"] as? String ?? "staff",
            storeId: json["store_id"] as? UUID
        )
    }
}