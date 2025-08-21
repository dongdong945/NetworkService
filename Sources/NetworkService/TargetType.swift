import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public enum NetworkTask {
    case requestPlain
    case requestData(Data)
    case requestJSONEncodable(Encodable)
    case requestParameters(parameters: [String: Any], encoding: ParameterEncoding)
}

public protocol TargetType {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: [String: String]? { get }
}

public protocol ParameterEncoding {
    func encode(_ urlRequest: inout URLRequest, with parameters: [String: Any]) throws
}

public struct URLEncoding: ParameterEncoding {
    public func encode(_ urlRequest: inout URLRequest, with parameters: [String: Any]) throws {
        guard let url = urlRequest.url else { return }

        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0, value: "\($1)") }
            urlRequest.url = urlComponents.url
        }
    }

    public init() {}
}

public struct JSONEncoding: ParameterEncoding {
    public func encode(_ urlRequest: inout URLRequest, with parameters: [String: Any]) throws {
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
    }

    public init() {}
}
