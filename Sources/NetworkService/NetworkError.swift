@preconcurrency import Foundation

/// 网络请求错误类型
public enum NetworkError: Error, Sendable {
    /// 无效的 URL
    case invalidURL
    /// 请求失败
    case requestFailed(Error)
    /// 解码失败
    case decodingFailed(Error)
    /// 无效的响应
    case invalidResponse
    /// 服务器错误
    case serverError(statusCode: Int, data: Data?)
}
