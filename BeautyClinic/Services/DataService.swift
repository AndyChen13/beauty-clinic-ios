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
            let notes: String?
            let introduction: String?
            let recommendedHotel: String?
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
                notes: r.notes,
                introduction: r.introduction,
                recommendedHotel: r.recommendedHotel,
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
            let notes: String?
            let introduction: String?
            let recommendedHotel: String?
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
            notes: r.notes,
            introduction: r.introduction,
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
            let notes: String?
            let introduction: String?
            let recommendedHotel: String?
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
            notes: r.notes,
            introduction: r.introduction,
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
            let notes: String?
            let introduction: String?
            let recommendedHotel: String?
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
            notes: r.notes,
            introduction: r.introduction,
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
            let firstTransactionDate: String?
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
                firstTransactionDate: parseISO8601Date(r.firstTransactionDate),
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
            let firstTransactionDate: String?
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
            firstTransactionDate: parseISO8601Date(r.firstTransactionDate),
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
            let firstTransactionDate: String?
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
            firstTransactionDate: parseISO8601Date(r.firstTransactionDate),
            firstTransactionAmount: r.firstTransactionAmount,
            amountReceived: r.amountReceived,
            outstandingAmount: r.outstandingAmount,
            conversionProbability: nil,
            remainingSessions: r.remainingSessions,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func getCustomer(id: UUID) async throws -> Customer {
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
            let firstTransactionDate: String?
            let firstTransactionAmount: Double?
            let amountReceived: Double?
            let outstandingAmount: Double?
            let conversionProbability: Int?
            let remainingSessions: Int?
            let createdAt: String?
            let updatedAt: String?
        }
        
        let r: CustomerResponse = try await APIClient.shared.get(path: "/api/customers/\(id.uuidString)")
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
            createdBy: r.createdBy.flatMap { UUID(uuidString: $0) },
            lastVisit: nil,
            firstTransactionDate: parseISO8601Date(r.firstTransactionDate),
            firstTransactionAmount: r.firstTransactionAmount,
            amountReceived: r.amountReceived,
            outstandingAmount: r.outstandingAmount,
            conversionProbability: r.conversionProbability,
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

// MARK: - Date Parsing Helper
private func parseISO8601Date(_ string: String?) -> Date? {
    guard let string = string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string)
}

// MARK: - Transaction Service
@MainActor
class TransactionService {
    static let shared = TransactionService()
    
    struct TransactionResponse: Codable {
        let id: String
        let customerId: String
        let storeId: String
        let packageId: String
        let staffUserId: String?
        let amount: Double
        let amountReceived: Double?
        let storeRebateAmount: Double?
        let outstandingAmount: Double?
        let totalSessions: Int
        let completedSessions: Int
        let transactionDate: String
        let firstDeliveryDate: String?
        let estimatedCompletionDate: String?
        let status: String
        let notes: String?
        let modifiedAt: String?
        let modifiedBy: String?
        let modifiedByName: String?
        let TransactionAuditLog: [AuditLogResponse]?
        let createdAt: String?
        let updatedAt: String?
        let branch: String?
        let customer: NameBrief?
        let store: NameBrief?
        let package: NameBrief?
        
        struct NameBrief: Codable {
            let name: String
        }
        
        struct AuditLogResponse: Codable {
            let id: String
            let transactionId: String
            let field: String
            let oldValue: String?
            let newValue: String?
            let editedBy: String?
            let editedByName: String?
            let editedAt: String?
        }
    }
    
    private func mapToTransaction(_ r: TransactionResponse) -> Transaction {
        let logs = r.TransactionAuditLog?.map { log in
            TransactionAuditLog(
                id: UUID(uuidString: log.id) ?? UUID(),
                transactionId: UUID(uuidString: log.transactionId) ?? UUID(),
                field: log.field,
                oldValue: log.oldValue,
                newValue: log.newValue,
                editedBy: log.editedBy,
                editedByName: log.editedByName,
                editedAt: parseISO8601Date(log.editedAt)
            )
        }
        var t = Transaction(
            id: UUID(uuidString: r.id)!,
            customerId: UUID(uuidString: r.customerId)!,
            storeId: UUID(uuidString: r.storeId)!,
            packageId: UUID(uuidString: r.packageId)!,
            staffUserId: r.staffUserId.flatMap { UUID(uuidString: $0) },
            amount: r.amount,
            amountReceived: r.amountReceived,
            storeRebateAmount: r.storeRebateAmount,
            outstandingAmount: r.outstandingAmount,
            totalSessions: r.totalSessions,
            completedSessions: r.completedSessions,
            transactionDate: parseISO8601Date(r.transactionDate) ?? Date(),
            firstDeliveryDate: parseISO8601Date(r.firstDeliveryDate),
            estimatedCompletionDate: parseISO8601Date(r.estimatedCompletionDate),
            status: TransactionStatus(rawValue: r.status) ?? .pending,
            notes: r.notes,
            modifiedAt: parseISO8601Date(r.modifiedAt),
            modifiedBy: r.modifiedBy,
            modifiedByName: r.modifiedByName,
            auditLogs: logs,
            createdAt: parseISO8601Date(r.createdAt),
            updatedAt: parseISO8601Date(r.updatedAt),
            branch: TransactionBranch(rawValue: r.branch ?? "光电") ?? .photoElectric
        )
        t.customerName = r.customer?.name
        t.storeName = r.store?.name
        t.packageName = r.package?.name
        return t
    }
    
    func listTransactions(storeId: String? = nil, customerId: String? = nil, status: String? = nil) async throws -> [Transaction] {
        var query: [String] = []
        if let storeId = storeId { query.append("storeId=\(storeId)") }
        if let customerId = customerId { query.append("customerId=\(customerId)") }
        if let status = status { query.append("status=\(status)") }
        let qs = query.isEmpty ? "" : "?" + query.joined(separator: "&")
        
        let responses: [TransactionResponse] = try await APIClient.shared.get(path: "/api/transactions" + qs)
        return responses.map(mapToTransaction)
    }
    
    func createTransaction(_ insert: TransactionInsert) async throws -> Transaction {
        let r: TransactionResponse = try await APIClient.shared.post(path: "/api/transactions", body: insert)
        return mapToTransaction(r)
    }
    
    func updateTransaction(id: String, data: TransactionUpdate) async throws -> Transaction {
        let responseData = try await APIClient.shared.dataRequest(path: "/api/transactions/\(id)", method: "PUT", body: data)
        return try decodeTransactionResponse(responseData)
    }

    func deleteTransaction(id: String) async throws {
        let responseData = try await APIClient.shared.dataRequest(path: "/api/transactions/\(id)", method: "DELETE")
        _ = try decodeDeleteResponse(responseData)
    }

    private func decodeTransactionResponse(_ data: Data) throws -> Transaction {
        let decoder = makeDecoder()
        if let approval = try? decoder.decode(OperationApprovalResponse.self, from: data), approval.requiresApproval == true {
            throw APIError.pendingApproval(approval.message ?? "已提交审批，等待超级管理员审核")
        }
        let r = try decoder.decode(TransactionResponse.self, from: data)
        return mapToTransaction(r)
    }

    private func decodeDeleteResponse(_ data: Data) throws -> DeleteTransactionResponse {
        let decoder = makeDecoder()
        if let approval = try? decoder.decode(OperationApprovalResponse.self, from: data), approval.requiresApproval == true {
            throw APIError.pendingApproval(approval.message ?? "已提交审批，等待超级管理员审核")
        }
        return try decoder.decode(DeleteTransactionResponse.self, from: data)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

struct OperationApprovalResponse: Codable {
    let success: Bool
    let message: String?
    let requiresApproval: Bool?
}

struct DeleteTransactionResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Delivery Service
@MainActor
class DeliveryService {
    static let shared = DeliveryService()
    
    struct DeliveryResponse: Codable {
        let id: String
        let transactionId: String
        let customerId: String
        let storeId: String
        let staffUserId: String?
        let sessionNumber: Int
        let deliveryDate: String
        let notes: String?
        let photos: [String]?
        let createdAt: String?
    }
    
    private func mapToDelivery(_ r: DeliveryResponse) -> Delivery {
        Delivery(
            id: UUID(uuidString: r.id)!,
            transactionId: UUID(uuidString: r.transactionId)!,
            customerId: UUID(uuidString: r.customerId)!,
            storeId: UUID(uuidString: r.storeId)!,
            staffUserId: r.staffUserId.flatMap { UUID(uuidString: $0) },
            sessionNumber: r.sessionNumber,
            deliveryDate: parseISO8601Date(r.deliveryDate) ?? Date(),
            notes: r.notes,
            photos: r.photos,
            createdAt: parseISO8601Date(r.createdAt)
        )
    }
    
    func listDeliveries(transactionId: String? = nil) async throws -> [Delivery] {
        var path = "/api/deliveries"
        if let tid = transactionId {
            path += "?transactionId=\(tid)"
        }
        let responses: [DeliveryResponse] = try await APIClient.shared.get(path: path)
        return responses.map(mapToDelivery)
    }
    
    func createDelivery(_ insert: DeliveryInsert) async throws -> Delivery {
        let r: DeliveryResponse = try await APIClient.shared.post(path: "/api/deliveries", body: insert)
        return mapToDelivery(r)
    }
}

// MARK: - Package Service
@MainActor
class PackageService {
    static let shared = PackageService()
    
    struct PackageResponse: Codable {
        let id: String
        let name: String
        let description: String?
        let category: String
        let price: Double
        let durationMinutes: Int
        let totalSessions: Int
        let imageUrl: String?
        let isActive: Bool
        let createdAt: String?
        let updatedAt: String?
        let trainingMats: [TrainingMaterialResponse]?
        
        struct TrainingMaterialResponse: Codable {
            let id: String
            let packageId: String?
            let category: String
            let storeId: String?
            let title: String
            let version: String
            let fileUrl: String
            let fileType: String
            let description: String?
            let uploadedBy: String?
            let isActive: Bool
            let createdAt: String?
            let updatedAt: String?
        }
    }
    
    private func mapToPackage(_ r: PackageResponse) -> ServicePackage {
        ServicePackage(
            id: UUID(uuidString: r.id)!,
            name: r.name,
            description: r.description,
            category: PackageCategory(rawValue: r.category) ?? .other,
            price: r.price,
            durationMinutes: r.durationMinutes,
            totalSessions: r.totalSessions,
            imageUrl: r.imageUrl,
            trainingMaterials: nil,
            isActive: r.isActive,
            createdAt: parseISO8601Date(r.createdAt),
            updatedAt: parseISO8601Date(r.updatedAt)
        )
    }
    
    private func mapToTrainingMaterial(_ r: PackageResponse.TrainingMaterialResponse) -> TrainingMaterial {
        TrainingMaterial(
            id: UUID(uuidString: r.id)!,
            packageId: r.packageId.flatMap { UUID(uuidString: $0) },
            category: TrainingMaterialCategory(rawValue: r.category) ?? .general,
            storeId: r.storeId.flatMap { UUID(uuidString: $0) },
            title: r.title,
            version: r.version,
            fileUrl: r.fileUrl,
            fileType: FileType(rawValue: r.fileType) ?? .pdf,
            description: r.description,
            uploadedBy: r.uploadedBy.flatMap { UUID(uuidString: $0) },
            isActive: r.isActive,
            createdAt: parseISO8601Date(r.createdAt),
            updatedAt: parseISO8601Date(r.updatedAt)
        )
    }
    
    func listPackages(category: String? = nil, isActive: Bool? = nil) async throws -> ([ServicePackage], [TrainingMaterial]) {
        var query: [String] = []
        if let category = category { query.append("category=\(category)") }
        if let isActive = isActive { query.append("isActive=\(isActive)") }
        let qs = query.isEmpty ? "" : "?" + query.joined(separator: "&")
        
        let responses: [PackageResponse] = try await APIClient.shared.get(path: "/api/packages" + qs)
        let packages = responses.map(mapToPackage)
        let materials = responses.compactMap { $0.trainingMats }.flatMap { $0.map(mapToTrainingMaterial) }
        return (packages, materials)
    }
    
    func createPackage(_ insert: ServicePackageInsert) async throws -> ServicePackage {
        let response: PackageResponse = try await APIClient.shared.post(path: "/api/packages", body: insert)
        return mapToPackage(response)
    }

    func updatePackage(id: UUID, insert: ServicePackageInsert) async throws -> ServicePackage {
        let response: PackageResponse = try await APIClient.shared.put(path: "/api/packages/\(id.uuidString)", body: insert)
        return mapToPackage(response)
    }

    func deletePackage(id: UUID) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
        }
        let _: DeleteResponse = try await APIClient.shared.delete(path: "/api/packages/\(id.uuidString)")
    }
}

// MARK: - Service Record Service
@MainActor
class ServiceRecordService {
    static let shared = ServiceRecordService()
    
    struct RecordResponse: Codable {
        let id: String
        let customerId: String
        let transactionId: String?
        let serviceDate: String
        let operatorId: String?
        let operatorName: String?
        let operatorPhone: String?
        let bodyPart: String?
        let serviceDetails: String?
        let photos: [String]?
        let customerFeedback: String?
        let extraPayment: Double
        let rebateAmount: Double
        let extraPaymentNote: String?
        let sessionsUsed: Int
        let remainingSessions: Int?
        let branch: String?
        let createdAt: String?
    }
    
    private func mapToRecord(_ r: RecordResponse) -> ServiceRecord {
        ServiceRecord(
            id: UUID(uuidString: r.id)!,
            customerId: UUID(uuidString: r.customerId)!,
            transactionId: r.transactionId.flatMap { UUID(uuidString: $0) },
            serviceDate: parseISO8601Date(r.serviceDate) ?? Date(),
            operatorId: r.operatorId.flatMap { UUID(uuidString: $0) },
            operatorName: r.operatorName,
            operatorPhone: r.operatorPhone,
            bodyPart: r.bodyPart,
            serviceDetails: r.serviceDetails,
            photos: r.photos,
            customerFeedback: r.customerFeedback,
            extraPayment: r.extraPayment,
            rebateAmount: r.rebateAmount,
            extraPaymentNote: r.extraPaymentNote,
            sessionsUsed: r.sessionsUsed,
            remainingSessions: r.remainingSessions,
            branch: r.branch ?? "光电",
            createdAt: parseISO8601Date(r.createdAt)
        )
    }
    
    func listRecords(customerId: String? = nil) async throws -> [ServiceRecord] {
        var path = "/api/service-records"
        if let cid = customerId {
            path += "?customerId=\(cid)"
        }
        let responses: [RecordResponse] = try await APIClient.shared.get(path: path)
        return responses.map(mapToRecord)
    }
    
    func createRecord(_ insert: ServiceRecordInsert) async throws -> ServiceRecord {
        let r: RecordResponse = try await APIClient.shared.post(path: "/api/service-records", body: insert)
        return mapToRecord(r)
    }
    
    func updateRecord(id: UUID, _ update: ServiceRecordUpdate) async throws -> ServiceRecord {
        let responseData = try await APIClient.shared.dataRequest(path: "/api/service-records/\(id.uuidString)", method: "PUT", body: update)
        return try decodeRecordResponse(responseData)
    }

    func deleteRecord(id: UUID) async throws {
        let responseData = try await APIClient.shared.dataRequest(path: "/api/service-records/\(id.uuidString)", method: "DELETE")
        _ = try decodeDeleteResponse(responseData)
    }

    private func decodeRecordResponse(_ data: Data) throws -> ServiceRecord {
        let decoder = makeDecoder()
        if let approval = try? decoder.decode(OperationApprovalResponse.self, from: data), approval.requiresApproval == true {
            throw APIError.pendingApproval(approval.message ?? "已提交审批，等待超级管理员审核")
        }
        let r = try decoder.decode(RecordResponse.self, from: data)
        return mapToRecord(r)
    }

    private func decodeDeleteResponse(_ data: Data) throws -> ServiceRecordDeleteResponse {
        let decoder = makeDecoder()
        if let approval = try? decoder.decode(OperationApprovalResponse.self, from: data), approval.requiresApproval == true {
            throw APIError.pendingApproval(approval.message ?? "已提交审批，等待超级管理员审核")
        }
        return try decoder.decode(ServiceRecordDeleteResponse.self, from: data)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

struct ServiceRecordDeleteResponse: Codable {
    let success: Bool
}

// MARK: - Deletion Request Service
@MainActor
class DeletionRequestService {
    static let shared = DeletionRequestService()
    
    struct RequestResponse: Codable {
        let id: String
        let requesterId: String
        let targetType: String
        let targetId: String
        let targetName: String?
        let reason: String?
        let status: String
        let adminNotes: String?
        let processedBy: String?
        let processedAt: String?
        let createdAt: String?
    }
    
    private func mapToRequest(_ r: RequestResponse) -> DeletionRequest {
        DeletionRequest(
            id: UUID(uuidString: r.id)!,
            requesterId: UUID(uuidString: r.requesterId)!,
            targetType: r.targetType,
            targetId: UUID(uuidString: r.targetId)!,
            targetName: r.targetName,
            reason: r.reason,
            status: RequestStatus(rawValue: r.status) ?? .pending,
            adminNotes: r.adminNotes,
            processedBy: r.processedBy.flatMap { UUID(uuidString: $0) },
            processedAt: parseISO8601Date(r.processedAt),
            createdAt: parseISO8601Date(r.createdAt)
        )
    }
    
    func listRequests() async throws -> [DeletionRequest] {
        let responses: [RequestResponse] = try await APIClient.shared.get(path: "/api/deletion-requests")
        return responses.map(mapToRequest)
    }
    
    func createRequest(_ insert: DeletionRequestInsert) async throws {
        let _: RequestResponse = try await APIClient.shared.post(path: "/api/deletion-requests", body: insert)
    }
    
    func approveRequest(id: UUID, adminNotes: String?) async throws {
        struct ApproveBody: Codable {
            let adminNotes: String?
        }
        let _: RequestResponse = try await APIClient.shared.put(
            path: "/api/deletion-requests/\(id.uuidString)/approve",
            body: ApproveBody(adminNotes: adminNotes)
        )
    }
    
    func rejectRequest(id: UUID, adminNotes: String?) async throws {
        struct RejectBody: Codable {
            let adminNotes: String?
        }
        let _: RequestResponse = try await APIClient.shared.put(
            path: "/api/deletion-requests/\(id.uuidString)/reject",
            body: RejectBody(adminNotes: adminNotes)
        )
    }
}


// MARK: - Training Material Service
@MainActor
class TrainingMaterialService {
    static let shared = TrainingMaterialService()
    
    private struct MaterialResponse: Codable {
        let id: String
        let packageId: String?
        let category: String
        let storeId: String?
        let title: String
        let version: String
        let fileUrl: String
        let fileType: String
        let description: String?
        let uploadedBy: String?
        let isActive: Bool
        let createdAt: String?
        let updatedAt: String?
    }
    
    func listMaterials(category: TrainingMaterialCategory? = nil, storeId: UUID? = nil) async throws -> [TrainingMaterial] {
        var queryItems: [String] = []
        if let category = category {
            queryItems.append("category=\(category.rawValue)")
        }
        if let storeId = storeId {
            queryItems.append("storeId=\(storeId.uuidString)")
        }
        let query = queryItems.isEmpty ? "" : "?" + queryItems.joined(separator: "&")
        
        let responses: [MaterialResponse] = try await APIClient.shared.get(path: "/api/training-materials" + query)
        return responses.map { r in
            TrainingMaterial(
                id: UUID(uuidString: r.id)!,
                packageId: r.packageId.flatMap { UUID(uuidString: $0) },
                category: TrainingMaterialCategory(rawValue: r.category) ?? .general,
                storeId: r.storeId.flatMap { UUID(uuidString: $0) },
                title: r.title,
                version: r.version,
                fileUrl: r.fileUrl,
                fileType: FileType(rawValue: r.fileType) ?? .pdf,
                description: r.description,
                uploadedBy: r.uploadedBy.flatMap { UUID(uuidString: $0) },
                isActive: r.isActive,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }
    
    func createMaterial(_ insert: TrainingMaterialInsert) async throws -> TrainingMaterial {
        let r: MaterialResponse = try await APIClient.shared.post(path: "/api/training-materials", body: insert)
        return TrainingMaterial(
            id: UUID(uuidString: r.id)!,
            packageId: r.packageId.flatMap { UUID(uuidString: $0) },
            category: TrainingMaterialCategory(rawValue: r.category) ?? .general,
            storeId: r.storeId.flatMap { UUID(uuidString: $0) },
            title: r.title,
            version: r.version,
            fileUrl: r.fileUrl,
            fileType: FileType(rawValue: r.fileType) ?? .pdf,
            description: r.description,
            uploadedBy: r.uploadedBy.flatMap { UUID(uuidString: $0) },
            isActive: r.isActive,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func updateMaterial(id: UUID, data: TrainingMaterialUpdate) async throws -> TrainingMaterial {
        let r: MaterialResponse = try await APIClient.shared.put(path: "/api/training-materials/\(id.uuidString)", body: data)
        return TrainingMaterial(
            id: UUID(uuidString: r.id)!,
            packageId: r.packageId.flatMap { UUID(uuidString: $0) },
            category: TrainingMaterialCategory(rawValue: r.category) ?? .general,
            storeId: r.storeId.flatMap { UUID(uuidString: $0) },
            title: r.title,
            version: r.version,
            fileUrl: r.fileUrl,
            fileType: FileType(rawValue: r.fileType) ?? .pdf,
            description: r.description,
            uploadedBy: r.uploadedBy.flatMap { UUID(uuidString: $0) },
            isActive: r.isActive,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    func deleteMaterial(id: UUID) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
        }
        let _: DeleteResponse = try await APIClient.shared.delete(path: "/api/training-materials/\(id.uuidString)")
    }
}

// MARK: - Dashboard Service
@MainActor
class DashboardService {
    static let shared = DashboardService()
    private init() {}

    struct DashboardSummaryResponse: Codable {
        struct BranchStats: Codable {
            let amount: Double
            let received: Double
            let outstanding: Double
            let count: Int
        }
        struct TodayMonth: Codable {
            let photoElectric: BranchStats
            let medicalBeauty: BranchStats
            let rebate: Double
        }
        struct TopStore: Codable {
            let storeId: String
            let name: String
            let amount: Double
        }
        struct TopCustomer: Codable {
            let customerId: String
            let name: String
            let amount: Double
        }
        let today: TodayMonth
        let month: TodayMonth
        let pendingCount: Int
        let customerCount: Int
        let topStores: [TopStore]
        let topCustomers: [TopCustomer]
    }

    func fetchSummary() async throws -> DashboardSummaryResponse {
        try await APIClient.shared.get(path: "/api/dashboard/summary")
    }
}

// MARK: - Store Rebate Service
@MainActor
class StoreRebateService {
    static let shared = StoreRebateService()
    private init() {}

    private func base(_ storeId: String) -> String { "/api/stores/\(storeId)/rebate" }

    func getActiveRebate(storeId: String) async throws -> StoreRebatePeriod? {
        do {
            let period: StoreRebatePeriod = try await APIClient.shared.get(path: base(storeId) + "/active")
            return period
        } catch APIError.serverError(let code, _) where code == 404 {
            return nil
        } catch {
            throw error
        }
    }

    func createRebate(storeId: String, insert: StoreRebatePeriodInsert) async throws -> StoreRebatePeriod {
        try await APIClient.shared.post(path: base(storeId), body: insert)
    }

    func closeRebate(storeId: String, manualRebate: Double?) async throws -> StoreRebatePeriod {
        struct Body: Codable { let manualRebate: Double? }
        return try await APIClient.shared.post(path: base(storeId) + "/close", body: Body(manualRebate: manualRebate))
    }

    func getRebateHistory(storeId: String) async throws -> [StoreRebatePeriod] {
        try await APIClient.shared.get(path: base(storeId) + "/history")
    }

    func updateHistoricalRebate(storeId: String, rebateId: String, confirmedRebate: Double) async throws -> StoreRebatePeriod {
        struct Body: Codable { let confirmedRebate: Double }
        return try await APIClient.shared.put(path: base(storeId) + "/history/\(rebateId)", body: Body(confirmedRebate: confirmedRebate))
    }

    func deleteHistoricalRebate(storeId: String, rebateId: String) async throws {
        struct Response: Codable { let success: Bool }
        let _: Response = try await APIClient.shared.delete(path: base(storeId) + "/history/\(rebateId)")
    }
}
