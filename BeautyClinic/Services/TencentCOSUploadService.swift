// Services/TencentCOSUploadService.swift
import Foundation

// MARK: - Configuration
enum COSConfig {
    static let bucket = "beautyclinic-images-1472260859"
    static let region = "ap-shanghai"
    static let domain = "https://\(bucket).cos.\(region).myqcloud.com"
    static let uploadEndpoint = "https://\(bucket).cos.\(region).myqcloud.com"
}

// MARK: - Upload Service
enum TencentCOSUploadService {
    
    /// Upload image data to Tencent Cloud COS via local Python sign server
    static func uploadImage(_ data: Data, key: String? = nil) async throws -> String {
        let fileKey = key ?? "\(UUID().uuidString).jpg"
        let encodedKey = fileKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileKey
        
        guard let url = URL(string: "\(COSConfig.uploadEndpoint)/\(encodedKey)") else {
            throw COSError.invalidURL
        }
        
        // Get authorization from local sign server
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
            throw COSError.uploadFailed("HTTP \(httpResponse.statusCode) - \(body)")
        }
        
        return "\(COSConfig.domain)/\(encodedKey)"
    }
    
    static func publicURL(for key: String) -> String {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return "\(COSConfig.domain)/\(encodedKey)"
    }
    
    // MARK: - Call Local Sign Server
    
    private static func fetchAuthorization(key: String) async throws -> String {
        let hosts = ["localhost", "127.0.0.1"]
        var lastError: Error?
        
        for host in hosts {
            do {
                guard let signURL = URL(string: "http://\(host):3000/sign") else { continue }
                
                var request = URLRequest(url: signURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "key": key,
                    "method": "put"
                ])
                request.timeoutInterval = 2
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
                guard let authorization = json?["authorization"] else {
                    continue
                }
                
                print("[COS] Sign server connected via \(host)")
                return authorization
            } catch {
                lastError = error
                print("[COS] Failed to connect to \(host):3000 - \(error.localizedDescription)")
            }
        }
        
        throw lastError ?? COSError.invalidResponse
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
