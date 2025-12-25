@preconcurrency import Foundation

// MARK: - HTTP Method

/// HTTP 请求方法
public enum HTTPMethod: String, Sendable {
    /// GET 请求
    case get = "GET"
    /// POST 请求
    case post = "POST"
    /// PUT 请求
    case put = "PUT"
    /// DELETE 请求
    case delete = "DELETE"
    /// PATCH 请求
    case patch = "PATCH"
}

// MARK: - Network Task

/// 网络请求任务类型
public enum NetworkTask: Sendable {
    /// 普通请求（无参数）
    case requestPlain
    /// 带 Data 的请求
    case requestData(Data)
    /// 带可编码对象的 JSON 请求
    case requestJSONEncodable(Encodable & Sendable)
    /// 带参数和编码方式的请求
    case requestParameters(parameters: [String: Sendable], encoding: ParameterEncoding)
}

// MARK: - Target Type

/// 网络请求目标协议
public protocol TargetType {
    /// 基础 URL
    var baseURL: URL { get }
    /// 路径
    var path: String { get }
    /// HTTP 方法
    var method: HTTPMethod { get }
    /// 请求任务
    var task: NetworkTask { get }
    /// 请求头
    var headers: [String: String]? { get }
}

// MARK: - Parameter Encoding

/// 参数编码协议
public protocol ParameterEncoding: Sendable {
    /// 编码参数到 URLRequest
    func encode(_ urlRequest: inout URLRequest, with parameters: [String: Sendable]) throws
}

// MARK: - URL Encoding

/// URL 参数编码（Query String）
public struct URLEncoding: ParameterEncoding {
    public init() {}

    /// 将参数编码为 URL query string
    public func encode(_ urlRequest: inout URLRequest, with parameters: [String: Sendable]) throws {
        guard let url = urlRequest.url else { return }

        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0, value: "\($1)") }
            urlRequest.url = urlComponents.url
        }
    }
}

// MARK: - JSON Encoding

/// JSON 参数编码
public struct JSONEncoding: ParameterEncoding {
    public init() {}

    /// 将参数编码为 JSON body
    public func encode(_ urlRequest: inout URLRequest, with parameters: [String: Sendable]) throws {
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
    }
}
