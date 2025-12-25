@preconcurrency import Foundation

// MARK: - Plugin Type

/// 网络请求插件协议
///
/// 用于在请求的不同阶段进行拦截和处理，例如：
/// - 添加认证 token
/// - 请求/响应日志
/// - 错误处理
/// - 请求重试
public protocol PluginType: Sendable {
    /// 准备请求（在发送前修改请求）
    /// - Parameters:
    ///   - request: 待发送的请求
    ///   - target: 请求目标
    /// - Returns: 修改后的请求
    func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest

    /// 即将发送请求（用于日志等）
    /// - Parameters:
    ///   - request: 即将发送的请求
    ///   - target: 请求目标
    func willSend(_ request: URLRequest, target: TargetType)

    /// 接收到响应或错误
    /// - Parameters:
    ///   - result: 响应结果或错误
    ///   - target: 请求目标
    func didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType)
}

// MARK: - Default Implementation

extension PluginType {
    /// 默认实现：不修改请求
    public func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest { request }

    /// 默认实现：不处理
    public func willSend(_ request: URLRequest, target: TargetType) {}

    /// 默认实现：不处理
    public func didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType) {}
}
