
import Foundation

public protocol PluginType {
    func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest
    func willSend(_ request: URLRequest, target: TargetType)
    func didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType)
}

extension PluginType {
    public func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest { request }
    public func willSend(_ request: URLRequest, target: TargetType) {}
    public func didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType) {}
}
