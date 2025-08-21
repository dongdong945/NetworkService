import Foundation

public struct SSEEvent {
    public let id: String?
    public let event: String?
    public let data: String?
    public let retry: String?
}

public class NetworkService {
    private let plugins: [PluginType]
    private let session: URLSession

    public init(session: URLSession = .shared, plugins: [PluginType] = []) {
        self.session = session
        self.plugins = plugins
    }

    public func request(_ target: TargetType) async throws -> Data {
        var urlRequest = try urlRequest(for: target)

        for plugin in plugins {
            urlRequest = await plugin.prepare(urlRequest, target: target)
        }

        plugins.forEach { $0.willSend(urlRequest, target: target) }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            plugins.forEach { $0.didReceive(.success((response, data)), target: target) }
            return data
        } catch {
            plugins.forEach { $0.didReceive(.failure(error), target: target) }
            throw error
        }
    }

    public func sse(_ target: TargetType) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream {
            continuation in
            Task {
                do {
                    var urlRequest = try self.urlRequest(for: target)
                    for plugin in plugins {
                        urlRequest = await plugin.prepare(urlRequest, target: target)
                    }

                    let sseParser = SSEParser {
                        event in
                        continuation.yield(event)
                    }

                    let task = session.dataTask(with: urlRequest) {
                        data, response, error in
                        if let error {
                            continuation.finish(throwing: error)
                            return
                        }
                        if let data {
                            sseParser.parse(data: data)
                        }
                    }
                    task.resume()

                    continuation.onTermination = {
                        @Sendable _ in
                        task.cancel()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

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

private final class SSEParser: @unchecked Sendable {
    private var onEvent: (SSEEvent) -> Void
    private var buffer = Data()

    init(onEvent: @escaping (SSEEvent) -> Void) {
        self.onEvent = onEvent
    }

    func parse(data: Data) {
        buffer.append(data)
        while let (event, remaining) = parseEvent(from: buffer) {
            onEvent(event)
            buffer = remaining
        }
    }

    private func parseEvent(from data: Data) -> (SSEEvent, Data)? {
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        let lines = string.components(separatedBy: .newlines)
        var id: String? = nil
        var event: String? = nil
        var data: String? = nil
        var retry: String? = nil
        var consumedLines = 0

        for line in lines {
            consumedLines += 1
            if line.isEmpty { // End of event
                if id != nil || event != nil || data != nil || retry != nil {
                    let sseEvent = SSEEvent(id: id, event: event, data: data, retry: retry)
                    let remainingData = lines.dropFirst(consumedLines).joined(separator: "\n").data(using: .utf8) ?? Data()
                    return (sseEvent, remainingData)
                }
            } else if line.hasPrefix(":") {
                // comment
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
