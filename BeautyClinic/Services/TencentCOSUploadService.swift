// Services/TencentCOSUploadService.swift
import Foundation

// MARK: - Configuration
enum COSConfig {
    static let bucket = "beautyclinic-images-1472260859"
    static let region = "ap-shanghai"
    
    static var secretId: String {
        loadCredential(key: "SecretId")
    }
    
    static var secretKey: String {
        loadCredential(key: "SecretKey")
    }
    
    static var domain: String {
        return "https://\(bucket).cos.\(region).myqcloud.com"
    }
    
    static var uploadEndpoint: String {
        return "https://\(bucket).cos.\(region).myqcloud.com"
    }
    
    private static func loadCredential(key: String) -> String {
        if let path = Bundle.main.path(forResource: "COSCredentials", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: String],
           let value = dict[key], !value.isEmpty, !value.hasPrefix("YOUR_") {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !value.isEmpty, !value.hasPrefix("YOUR_") {
            return value
        }
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
        
        // Try local Python sign server first, fallback to client-side signature
        let authorization = try await fetchAuthorization(key: fileKey)
        
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
            throw COSError.uploadFailed("HTTP \(httpResponse.statusCode) - \(body)")
        }
        
        return "\(COSConfig.domain)/\(encodedKey)"
    }
    
    static func publicURL(for key: String) -> String {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return "\(COSConfig.domain)/\(encodedKey)"
    }
    
    // MARK: - Authorization (Local Server + Fallback)
    
    private static func fetchAuthorization(key: String) async throws -> String {
        // 1. Try local Python sign server
        if let auth = try? await callLocalSignServer(key: key) {
            print("[COS] Using local sign server")
            return auth
        }
        
        // 2. Fallback: client-side signature (may fail with 403)
        print("[COS] Local sign server unavailable, using client-side signature")
        return try clientSideSign(key: key)
    }
    
    private static func callLocalSignServer(key: String) async throws -> String {
        guard let url = URL(string: "http://localhost:3000/sign") else {
            throw COSError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "key": key,
            "method": "put"
        ])
        request.timeoutInterval = 2 // Quick timeout if server not running
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw COSError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        guard let authorization = json?["authorization"] else {
            throw COSError.encodingFailed
        }
        
        return authorization
    }
    
    // MARK: - Client-side Signature (Fallback)
    
    private static func clientSideSign(key: String) throws -> String {
        let startTime = Int(Date().timeIntervalSince1970)
        let endTime = startTime + 3600
        let keyTime = "\(startTime);\(endTime)"
        
        let httpMethod = "put"
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        let httpURI = "/\(encodedKey)"
        let host = "\(COSConfig.bucket).cos.\(COSConfig.region).myqcloud.com"
        let httpHeaders = "host=\(host)"
        let httpString = "\(httpMethod)\n\(httpURI)\n\n\(httpHeaders)\n"
        
        // SHA1
        let httpStringHash = sha1Hex(httpString)
        let stringToSign = "sha1\n\(keyTime)\n\(httpStringHash)\n"
        
        // HMAC-SHA1 using CommonCrypto
        guard let secretKeyData = COSConfig.secretKey.data(using: .utf8),
              let keyTimeData = keyTime.data(using: .utf8),
              let stringToSignData = stringToSign.data(using: .utf8) else {
            throw COSError.encodingFailed
        }
        
        let signKey = hmacSHA1(key: secretKeyData, message: keyTimeData)
        let signature = hmacSHA1(key: signKey, message: stringToSignData)
        let signatureBase64 = signature.base64EncodedString()
        
        return "q-sign-algorithm=sha1&q-ak=\(COSConfig.secretId)&q-sign-time=\(keyTime)&q-key-time=\(keyTime)&q-header-list=host&q-url-param-list=&q-signature=\(signatureBase64)"
    }
    
    // MARK: - Crypto Helpers (CommonCrypto)
    
    private static func hmacSHA1(key: Data, message: Data) -> Data {
        var result = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
        result.withUnsafeMutableBytes { resultBytes in
            key.withUnsafeBytes { keyBytes in
                message.withUnsafeBytes { messageBytes in
                    CCHmac(
                        CCHmacAlgorithm(kCCHmacAlgSHA1),
                        keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        key.count,
                        messageBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        message.count,
                        resultBytes.bindMemory(to: UInt8.self).baseAddress
                    )
                }
            }
        }
        return result
    }
    
    private static func sha1Hex(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                CC_SHA1(baseAddress, CC_LONG(data.count), &digest)
            }
        }
        return digest.map { String(format: "%02x", $0) }.joined()
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
