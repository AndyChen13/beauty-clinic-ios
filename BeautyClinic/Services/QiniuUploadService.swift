// Services/QiniuUploadService.swift
import Foundation
import CryptoKit

// MARK: - Configuration
// TODO: Replace with your actual Qiniu credentials after registration
enum QiniuConfig {
    static let accessKey = "YOUR_ACCESS_KEY"
    static let secretKey = "YOUR_SECRET_KEY"
    static let bucket = "YOUR_BUCKET_NAME"
    static let domain = "YOUR_DOMAIN" // e.g., "https://xxx.qiniudn.com"
    static let uploadURL = "https://up-z2.qiniup.com" // 华南节点
}

// MARK: - Upload Service
enum QiniuUploadService {
    
    /// Upload image data to Qiniu Kodo
    /// - Parameters:
    ///   - data: Image data
    ///   - key: Optional custom key (filename). If nil, uses UUID.
    /// - Returns: Public URL of the uploaded file
    static func uploadImage(_ data: Data, key: String? = nil) async throws -> String {
        let fileKey = key ?? "\(UUID().uuidString).jpg"
        let token = try generateUploadToken(key: fileKey)
        
        guard let url = URL(string: QiniuConfig.uploadURL) else {
            throw QiniuError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = createMultipartBody(token: token, key: fileKey, fileData: data)
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QiniuError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw QiniuError.uploadFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        // Parse response
        struct UploadResponse: Decodable {
            let key: String
            let hash: String
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: responseData)
        
        // Build public URL
        let publicURL = "\(QiniuConfig.domain)/\(uploadResponse.key)"
        return publicURL
    }
    
    /// Build public URL for a given key
    static func publicURL(for key: String) -> String {
        return "\(QiniuConfig.domain)/\(key)"
    }
    
    // MARK: - Private
    
    private static let boundary = "Boundary-\(UUID().uuidString)"
    
    private static func generateUploadToken(key: String) throws -> String {
        let deadline = Int(Date().timeIntervalSince1970) + 3600 // 1 hour expiry
        
        let putPolicy: [String: Any] = [
            "scope": "\(QiniuConfig.bucket):\(key)",
            "deadline": deadline,
            "returnBody": "{\"key\":$(key),\"hash\":$(etag),\"name\":$(fname)}"
        ]
        
        let putPolicyData = try JSONSerialization.data(withJSONObject: putPolicy)
        let encodedPutPolicy = base64URLSafeEncode(putPolicyData)
        
        guard let secretKeyData = QiniuConfig.secretKey.data(using: .utf8),
              let encodedData = encodedPutPolicy.data(using: .utf8) else {
            throw QiniuError.encodingFailed
        }
        
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: encodedData, using: .init(data: secretKeyData))
        let signatureData = Data(signature)
        let encodedSign = base64URLSafeEncode(signatureData)
        
        return "\(QiniuConfig.accessKey):\(encodedSign):\(encodedPutPolicy)"
    }
    
    private static func createMultipartBody(token: String, key: String, fileData: Data) -> Data {
        var body = Data()
        
        // Token field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(token)\r\n".data(using: .utf8)!)
        
        // Key field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(key)\r\n".data(using: .utf8)!)
        
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(key)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private static func base64URLSafeEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Errors
enum QiniuError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case uploadFailed(String)
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的七牛云上传 URL"
        case .invalidResponse:
            return "服务器响应无效"
        case .uploadFailed(let msg):
            return "上传失败: \(msg)"
        case .encodingFailed:
            return "Token 编码失败"
        }
    }
}
