@preconcurrency import Foundation

// MARK: - SSE Event

/// Server-Sent Events (SSE) 事件
public struct SSEEvent: Sendable {
    /// 事件 ID
    public let id: String?
    /// 事件类型
    public let event: String?
    /// 事件数据
    public let data: String?
    /// 重试间隔（毫秒）
    public let retry: String?
}

// MARK: - Network Service

/// 网络服务
///
/// 提供统一的网络请求接口，支持：
/// - 标准 HTTP 请求
/// - Server-Sent Events (SSE) 流式请求
/// - 插件系统（日志、认证等）
///
/// 线程安全：
/// 此类使用 @unchecked Sendable 因为：
/// 1. 所有属性都是不可变的（let 绑定）
/// 2. URLSession 内部是线程安全的
/// 3. plugins 数组初始化后永不修改
/// 4. 所有并发访问都是只读的
public final class NetworkService: @unchecked Sendable {
    // MARK: - Properties

    /// 插件列表
    private let plugins: [PluginType]
    /// URL 会话
    private let session: URLSession

    // MARK: - Initialization

    /// 初始化网络服务
    /// - Parameters:
    ///   - session: URL 会话，默认为 .shared
    ///   - plugins: 插件列表，默认为空
    public init(session: URLSession = .shared, plugins: [PluginType] = []) {
        self.session = session
        self.plugins = plugins
    }

    // MARK: - Public Methods

    /// 发送网络请求
    /// - Parameter target: 请求目标
    /// - Returns: 响应数据
    /// - Throws: 网络错误
    @available(iOS 15.0, *)
    public func request(_ target: TargetType) async throws -> Data {
        var urlRequest = try urlRequest(for: target)

        // 应用插件准备请求
        for plugin in plugins {
            urlRequest = await plugin.prepare(urlRequest, target: target)
        }

        // 通知插件即将发送请求
        plugins.forEach { $0.willSend(urlRequest, target: target) }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            // 通知插件请求成功
            plugins.forEach { $0.didReceive(.success((response, data)), target: target) }
            return data
        } catch {
            // 通知插件请求失败
            plugins.forEach { $0.didReceive(.failure(error), target: target) }
            throw error
        }
    }

    /// 创建 Server-Sent Events (SSE) 流
    /// - Parameter target: 请求目标
    /// - Returns: SSE 事件流
    @available(iOS 15.0, *)
    public func sse<T: TargetType & Sendable>(_ target: T) -> AsyncThrowingStream<SSEEvent, Error> {
        // 捕获不可变值以避免捕获 self
        let session = self.session
        let plugins = self.plugins

        // 在流外部创建 URLRequest 以避免捕获 self
        let urlRequestResult: Result<URLRequest, Error>
        do {
            urlRequestResult = .success(try self.urlRequest(for: target))
        } catch {
            urlRequestResult = .failure(error)
        }

        return AsyncThrowingStream { continuation in
            Task {
                var urlRequest: URLRequest
                switch urlRequestResult {
                case .success(let request):
                    urlRequest = request
                case .failure(let error):
                    continuation.finish(throwing: error)
                    return
                }

                // 应用插件准备请求
                for plugin in plugins {
                    urlRequest = await plugin.prepare(urlRequest, target: target)
                }

                let sseParser = SSEParser { event in
                    continuation.yield(event)
                }

                let task = session.dataTask(with: urlRequest) { [sseParser] data, response, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    if let data {
                        sseParser.parse(data: data)
                    }
                }
                task.resume()

                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }
    }

    // MARK: - Private Methods

    /// 根据目标创建 URLRequest
    /// - Parameter target: 请求目标
    /// - Returns: URLRequest
    /// - Throws: 编码错误
    private func urlRequest(for target: TargetType) throws -> URLRequest {
        let url = target.baseURL.appendingPathComponent(target.path)
        var request = URLRequest(url: url)
        request.httpMethod = target.method.rawValue
        request.allHTTPHeaderFields = target.headers

        switch target.task {
        case .requestPlain:
            break
        case .requestData(let data):
            request.httpBody = data
        case .requestJSONEncodable(let encodable):
            request.httpBody = try JSONEncoder().encode(encodable)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .requestParameters(let parameters, let encoding):
            try encoding.encode(&request, with: parameters)
        }

        return request
    }
}

// MARK: - SSE Parser

/// SSE 事件解析器
///
/// 注意：使用 @unchecked Sendable 是安全的，因为：
/// 1. SSEParser 只在 dataTask 的 completion handler 中使用
/// 2. dataTask 的 completion handler 总是在同一个队列上串行调用
/// 3. 不存在跨线程并发访问的情况
private final class SSEParser: @unchecked Sendable {
    // MARK: - Properties

    /// 事件回调
    private var onEvent: (SSEEvent) -> Void
    /// 数据缓冲区
    private var buffer = Data()

    // MARK: - Initialization

    /// 初始化解析器
    /// - Parameter onEvent: 事件回调
    init(onEvent: @escaping (SSEEvent) -> Void) {
        self.onEvent = onEvent
    }

    // MARK: - Methods

    /// 解析数据
    /// - Parameter data: 待解析的数据
    func parse(data: Data) {
        buffer.append(data)
        while let (event, remaining) = parseEvent(from: buffer) {
            onEvent(event)
            buffer = remaining
        }
    }

    /// 从数据中解析单个事件
    /// - Parameter data: 数据
    /// - Returns: 事件和剩余数据（如果成功解析）
    private func parseEvent(from data: Data) -> (SSEEvent, Data)? {
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        let lines = string.components(separatedBy: .newlines)
        var id: String?
        var event: String?
        var data: String?
        var retry: String?
        var consumedLines = 0

        for line in lines {
            consumedLines += 1
            if line.isEmpty {
                // 空行表示事件结束
                if id != nil || event != nil || data != nil || retry != nil {
                    let sseEvent = SSEEvent(id: id, event: event, data: data, retry: retry)
                    let remainingData = lines.dropFirst(consumedLines).joined(separator: "\n").data(using: .utf8) ?? Data()
                    return (sseEvent, remainingData)
                }
            } else if line.hasPrefix(":") {
                // 注释行，忽略
                continue
            } else {
                let parts = line.components(separatedBy: ":")
                guard parts.count >= 2 else {
                    continue
                }
                let field = parts[0]
                let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

                switch field {
                case "id":
                    id = value
                case "event":
                    event = value
                case "data":
                    data = (data ?? "") + value + "\n"
                case "retry":
                    retry = value
                default:
                    break
                }
            }
        }
        return nil
    }
}
