// Services/TencentCOSUploadService.swift
import Foundation
import CryptoKit

// MARK: - Configuration
// Non-sensitive config (bucket & region)
enum COSConfig {
    static let bucket = "beautyclinic-images-1472260859"
    static let region = "ap-shanghai"
    
    /// SecretId & SecretKey loaded from COSCredentials.plist (gitignored)
    static var secretId: String {
        loadCredential(key: "SecretId")
    }
    
    static var secretKey: String {
        loadCredential(key: "SecretKey")
    }
    
    /// Default domain for public access
    static var domain: String {
        return "https://\(bucket).cos.\(region).myqcloud.com"
    }
    
    /// Upload endpoint
    static var uploadEndpoint: String {
        return "https://\(bucket).cos.\(region).myqcloud.com"
    }
    
    private static func loadCredential(key: String) -> String {
        // 1. Try COSCredentials.plist (local, gitignored)
        if let path = Bundle.main.path(forResource: "COSCredentials", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: String],
           let value = dict[key], !value.isEmpty, !value.hasPrefix("YOUR_") {
            return value
        }
        
        // 2. Fallback: try Info.plist
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !value.isEmpty, !value.hasPrefix("YOUR_") {
            return value
        }
        
        // 3. Fatal for missing credentials
        fatalError("Missing COS credential '\(key)'. Please set it in COSCredentials.plist or Info.plist.")
    }
}

// MARK: - Upload Service
enum TencentCOSUploadService {
    
    /// Upload image data to Tencent Cloud COS
    static func uploadImage(_ data: Data, key: String? = nil) async throws -> String {
        let fileKey = key ?? "\(UUID().uuidString).jpg"
        let encodedKey = fileKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileKey
        
        guard let url = URL(string: "\(COSConfig.uploadEndpoint)/\(encodedKey)") else {
            throw COSError.invalidURL
        }
        
        let authorization = try generateAuthorization(key: fileKey)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(COSConfig.bucket + ".cos." + COSConfig.region + ".myqcloud.com", forHTTPHeaderField: "Host")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw COSError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "no body"
            print("[COS Upload Error] HTTP \(httpResponse.statusCode), Body: \(body)")
            print("[COS Upload Error] Authorization: \(authorization)")
            throw COSError.uploadFailed("HTTP \(httpResponse.statusCode) - \(body)")
        }
        
        let publicURL = "\(COSConfig.domain)/\(encodedKey)"
        return publicURL
    }
    
    /// Build public URL for a given key
    static func publicURL(for key: String) -> String {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return "\(COSConfig.domain)/\(encodedKey)"
    }
    
    // MARK: - COS Signature V1
    
    private static func generateAuthorization(key: String) throws -> String {
        let startTime = Int(Date().timeIntervalSince1970)
        let endTime = startTime + 3600 // 1 hour expiry
        let keyTime = "\(startTime);\(endTime)"
        
        // SignKey = HMAC-SHA1(SecretKey, KeyTime)
        guard let secretKeyData = COSConfig.secretKey.data(using: .utf8),
              let keyTimeData = keyTime.data(using: .utf8) else {
            throw COSError.encodingFailed
        }
        let signKey = hmacSHA1(key: secretKeyData, message: keyTimeData)
        
        // Build HttpString
        let httpMethod = "put"
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        let httpURI = "/\(encodedKey)"
        let httpParameters = "" // No query params
        let host = "\(COSConfig.bucket).cos.\(COSConfig.region).myqcloud.com"
        let contentTypeEncoded = "image/jpeg".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "image/jpeg"
        let httpHeaders = "content-type=\(contentTypeEncoded)&host=\(host)"
        let httpString = "\(httpMethod)\n\(httpURI)\n\(httpParameters)\n\(httpHeaders)\n"
        
        // StringToSign = sha1\nKeyTime\nsha1(HttpString)\n
        let httpStringHash = sha1Hex(httpString)
        let stringToSign = "sha1\n\(keyTime)\n\(httpStringHash)\n"
        
        // Signature = HMAC-SHA1(StringToSign, SignKey)
        guard let stringToSignData = stringToSign.data(using: .utf8) else {
            throw COSError.encodingFailed
        }
        let signature = hmacSHA1(key: signKey, message: stringToSignData)
        let signatureBase64 = signature.base64EncodedString()
        
        let authorization = "q-sign-algorithm=sha1&q-ak=\(COSConfig.secretId)&q-sign-time=\(keyTime)&q-key-time=\(keyTime)&q-header-list=content-type;host&q-url-param-list=&q-signature=\(signatureBase64)"
        
        // Debug log
        print("[COS Debug] keyTime: \(keyTime)")
        print("[COS Debug] httpString: \(httpString.replacingOccurrences(of: "\n", with: "\\n"))")
        print("[COS Debug] stringToSign: \(stringToSign.replacingOccurrences(of: "\n", with: "\\n"))")
        print("[COS Debug] auth: \(authorization.prefix(80))...")
        
        return authorization
    }
    
    // MARK: - Crypto Helpers
    
    private static func hmacSHA1(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey)
        return Data(signature)
    }
    
    private static func sha1Hex(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        let hash = Insecure.SHA1.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors
enum COSError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case uploadFailed(String)
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 COS URL"
        case .invalidResponse:
            return "服务器响应无效"
        case .uploadFailed(let msg):
            return "上传失败: \(msg)"
        case .encodingFailed:
            return "签名编码失败"
        }
    }
}
