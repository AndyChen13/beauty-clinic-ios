import Foundation

// MARK: - Store Service
@MainActor
class StoreService {
    static let shared = StoreService()
    
    func listStores(status: String? = nil) async throws -> [Store] {
        var path = "/api/stores"
        if let status = status {
            path += "?status=\(status)"
        }
        
        struct StoreResponse: Codable {
            let id: String
            let name: String
            let address: String?
            let phone: String?
            let status: String
            let managerId: String?
            let imageUrl: String?
            let createdAt: String?
            let updatedAt: String?
        }
        
        let responses: [StoreResponse] = try await APIClient.shared.get(path: path)
        return responses.map { r in
            Store(
                id: UUID(uuidString: r.id)!,
                name: r.name,
                address: r.address,
                phone: r.phone,
                status: StoreStatus(rawValue: r.status) ?? .pending,
                managerId: r.managerId.flatMap { UUID(uuidString: $0) },
                imageUrl: r.imageUrl,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }
    
    func getStore(id: UUID) async throws -> Store {
        struct StoreResponse: Codable {
            let id: String
            let name: String
            let address: String?
            let phone: String?
            let status: String
            let managerId: String?
            let imageUrl: String?
            let createdAt: String?
            let updatedAt: String?
        }
        
        let r: StoreResponse = try await APIClient.shared.get(path: "/api/stores/\(id.uuidString)")
        return Store(
            id: UUID(uuidString: r.id)!,
            name: r.name,
            address: r.address,
            phone: r.phone,
            status: StoreStatus(rawValue: r.status) ?? .pending,
            managerId: r.managerId.flatMap { UUID(uuidString: $0) },
            imageUrl: r.imageUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func createStore(_ insert: StoreInsert) async throws -> Store {
        struct StoreResponse: Codable {
            let id: String
            let name: String
            let address: String?
            let phone: String?
            let status: String
            let managerId: String?
            let imageUrl: String?
        }
        
        let r: StoreResponse = try await APIClient.shared.post(path: "/api/stores", body: insert)
        return Store(
            id: UUID(uuidString: r.id)!,
            name: r.name,
            address: r.address,
            phone: r.phone,
            status: StoreStatus(rawValue: r.status) ?? .pending,
            managerId: r.managerId.flatMap { UUID(uuidString: $0) },
            imageUrl: r.imageUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func updateStore(id: UUID, data: StoreInsert) async throws -> Store {
        struct StoreResponse: Codable {
            let id: String
            let name: String
            let address: String?
            let phone: String?
            let status: String
            let managerId: String?
            let imageUrl: String?
        }
        
        let r: StoreResponse = try await APIClient.shared.put(
            path: "/api/stores/\(id.uuidString)",
            body: data
        )
        return Store(
            id: UUID(uuidString: r.id)!,
            name: r.name,
            address: r.address,
            phone: r.phone,
            status: StoreStatus(rawValue: r.status) ?? .pending,
            managerId: r.managerId.flatMap { UUID(uuidString: $0) },
            imageUrl: r.imageUrl,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func deleteStore(id: UUID) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
        }
        let _: DeleteResponse = try await APIClient.shared.delete(path: "/api/stores/\(id.uuidString)")
    }
}

// MARK: - Customer Service
@MainActor
class CustomerService {
    static let shared = CustomerService()
    
    func listCustomers(storeId: UUID? = nil, search: String? = nil) async throws -> [Customer] {
        var queryItems: [String] = []
        if let storeId = storeId {
            queryItems.append("storeId=\(storeId.uuidString)")
        }
        if let search = search, !search.isEmpty {
            queryItems.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }
        let query = queryItems.isEmpty ? "" : "?" + queryItems.joined(separator: "&")
        
        struct CustomerResponse: Codable {
            let id: String
            let phone: String
            let name: String
            let gender: String?
            let birthdate: String?
            let medicalHistory: String?
            let preferences: [String: String]?
            let photoUrl: String?
            let associatedStoreId: String?
            let createdBy: String?
            let lastVisit: String?
            let firstTransactionAmount: Double?
            let amountReceived: Double?
            let outstandingAmount: Double?
            let conversionProbability: Int?
            let remainingSessions: Int?
            let createdAt: String?
            let updatedAt: String?
        }
        
        let responses: [CustomerResponse] = try await APIClient.shared.get(path: "/api/customers" + query)
        return responses.map { r in
            Customer(
                id: UUID(uuidString: r.id)!,
                phone: r.phone,
                name: r.name,
                gender: r.gender,
                birthdate: r.birthdate,
                medicalHistory: r.medicalHistory,
                preferences: r.preferences,
                photoUrl: r.photoUrl,
                associatedStoreId: r.associatedStoreId.flatMap { UUID(uuidString: $0) },
                createdBy: r.createdBy.flatMap { UUID(uuidString: $0) },
                lastVisit: nil,
                firstTransactionAmount: r.firstTransactionAmount,
                amountReceived: r.amountReceived,
                outstandingAmount: r.outstandingAmount,
                conversionProbability: r.conversionProbability,
                remainingSessions: r.remainingSessions,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }
    
    func createCustomer(_ insert: CustomerInsert) async throws -> Customer {
        struct CustomerResponse: Codable {
            let id: String
            let phone: String
            let name: String
            let gender: String?
            let birthdate: String?
            let medicalHistory: String?
            let preferences: [String: String]?
            let photoUrl: String?
            let associatedStoreId: String?
            let firstTransactionAmount: Double?
            let amountReceived: Double?
            let outstandingAmount: Double?
            let remainingSessions: Int?
        }
        
        let r: CustomerResponse = try await APIClient.shared.post(
            path: "/api/customers",
            body: insert
        )
        return Customer(
            id: UUID(uuidString: r.id)!,
            phone: r.phone,
            name: r.name,
            gender: r.gender,
            birthdate: r.birthdate,
            medicalHistory: r.medicalHistory,
            preferences: r.preferences,
            photoUrl: r.photoUrl,
            associatedStoreId: r.associatedStoreId.flatMap { UUID(uuidString: $0) },
            createdBy: nil,
            lastVisit: nil,
            firstTransactionAmount: r.firstTransactionAmount,
            amountReceived: r.amountReceived,
            outstandingAmount: r.outstandingAmount,
            conversionProbability: nil,
            remainingSessions: r.remainingSessions,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func updateCustomer(id: UUID, data: CustomerInsert) async throws -> Customer {
        struct CustomerResponse: Codable {
            let id: String
            let phone: String
            let name: String
            let gender: String?
            let birthdate: String?
            let medicalHistory: String?
            let preferences: [String: String]?
            let photoUrl: String?
            let associatedStoreId: String?
            let firstTransactionAmount: Double?
            let amountReceived: Double?
            let outstandingAmount: Double?
            let remainingSessions: Int?
        }
        
        let r: CustomerResponse = try await APIClient.shared.put(
            path: "/api/customers/\(id.uuidString)",
            body: data
        )
        return Customer(
            id: UUID(uuidString: r.id)!,
            phone: r.phone,
            name: r.name,
            gender: r.gender,
            birthdate: r.birthdate,
            medicalHistory: r.medicalHistory,
            preferences: r.preferences,
            photoUrl: r.photoUrl,
            associatedStoreId: r.associatedStoreId.flatMap { UUID(uuidString: $0) },
            createdBy: nil,
            lastVisit: nil,
            firstTransactionAmount: r.firstTransactionAmount,
            amountReceived: r.amountReceived,
            outstandingAmount: r.outstandingAmount,
            conversionProbability: nil,
            remainingSessions: r.remainingSessions,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func deleteCustomer(id: UUID) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
        }
        let _: DeleteResponse = try await APIClient.shared.delete(
            path: "/api/customers/\(id.uuidString)"
        )
    }
}
