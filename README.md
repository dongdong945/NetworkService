# NetworkService

A modern Swift networking library built with Swift 5.5+ that provides a clean, type-safe API for HTTP requests and Server-Sent Events (SSE) streaming. Zero external dependencies, using only Foundation framework.

## Features

- ✅ Modern Swift concurrency (`async/await`)
- ✅ Type-safe API definitions
- ✅ Server-Sent Events (SSE) support
- ✅ Plugin/middleware architecture
- ✅ Zero external dependencies
- ✅ Protocol-oriented design
- ✅ Support for all major HTTP methods
- ✅ Multiple parameter encoding strategies

## Requirements

- Swift 5.5+
- macOS 12.0+, iOS 15.0+, tvOS 15.0+, watchOS 8.0+

## Installation

### Swift Package Manager

Add NetworkService to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/NetworkService", from: "1.0.0")
]
```

Or add it through Xcode:
1. File > Add Package Dependencies...
2. Enter the repository URL
3. Choose version requirements

## Quick Start

### 1. Define API Endpoints

Create an enum that conforms to `TargetType`:

```swift
import NetworkService

enum GitHubAPI {
    case userProfile(username: String)
    case createRepository(name: String, description: String)
}

extension GitHubAPI: TargetType {
    var baseURL: URL {
        return URL(string: "https://api.github.com")!
    }
    
    var path: String {
        switch self {
        case .userProfile(let username):
            return "/users/\(username)"
        case .createRepository:
            return "/user/repos"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .userProfile:
            return .get
        case .createRepository:
            return .post
        }
    }
    
    var task: NetworkTask {
        switch self {
        case .userProfile:
            return .requestPlain
        case .createRepository(let name, let description):
            let params = ["name": name, "description": description]
            return .requestParameters(parameters: params, encoding: JSONEncoding())
        }
    }
    
    var headers: [String: String]? {
        return ["Accept": "application/json"]
    }
}
```

### 2. Make HTTP Requests

```swift
let networkService = NetworkService()

// Simple GET request
let userData = try await networkService.request(GitHubAPI.userProfile(username: "octocat"))
let user = try JSONDecoder().decode(User.self, from: userData)

// POST request with JSON body
struct Repository: Codable {
    let name: String
    let description: String
}

let repoData = Repository(name: "MyApp", description: "An awesome app")
let responseData = try await networkService.request(GitHubAPI.createRepository(name: repoData.name, description: repoData.description))
```

### 3. Server-Sent Events (SSE)

```swift
enum SSEEndpoint: TargetType {
    case events
    
    var baseURL: URL { URL(string: "https://example.com")! }
    var path: String { "/events" }
    var method: HTTPMethod { .get }
    var task: NetworkTask { .requestPlain }
    var headers: [String: String]? { ["Accept": "text/event-stream"] }
}

// Stream SSE events
for try await event in networkService.sse(SSEEndpoint.events) {
    print("Event ID: \(event.id ?? "none")")
    print("Event Type: \(event.event ?? "message")")
    print("Data: \(event.data ?? "")")
    
    if let retry = event.retry {
        print("Retry after: \(retry) seconds")
    }
}
```

## Advanced Usage

### Custom Parameter Encoding

```swift
// URL encoding (query parameters)
.requestParameters(parameters: ["page": 1, "limit": 20], encoding: URLEncoding())

// JSON encoding (request body)
.requestParameters(parameters: ["name": "John", "age": 30], encoding: JSONEncoding())

// Raw data
let jsonData = try JSONEncoder().encode(someObject)
.requestData(jsonData)

// Encodable objects (automatic JSON encoding)
.requestJSONEncodable(someEncodableObject)
```

### Plugin System

Create custom plugins for logging, authentication, etc:

```swift
struct LoggingPlugin: PluginType {
    func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest {
        print("🚀 Preparing request to \(request.url?.absoluteString ?? "unknown")")
        return request
    }
    
    func willSend(_ request: URLRequest, target: TargetType) {
        print("📤 Sending \(request.httpMethod ?? "GET") request")
    }
    
    func didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType) {
        switch result {
        case .success(let (response, data)):
            print("✅ Received \(data.count) bytes")
        case .failure(let error):
            print("❌ Request failed: \(error)")
        }
    }
}

// Use with NetworkService
let networkService = NetworkService(plugins: [LoggingPlugin()])
```

### Authentication Plugin Example

```swift
struct AuthenticationPlugin: PluginType {
    private let token: String
    
    init(token: String) {
        self.token = token
    }
    
    func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest {
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }
}

let authPlugin = AuthenticationPlugin(token: "your-api-token")
let networkService = NetworkService(plugins: [authPlugin])
```

## API Reference

### NetworkService

The main networking client:

```swift
public class NetworkService {
    public init(session: URLSession = .shared, plugins: [PluginType] = [])
    
    // Standard HTTP requests
    public func request(_ target: TargetType) async throws -> Data
    
    // Server-Sent Events streaming
    public func sse(_ target: TargetType) -> AsyncThrowingStream<SSEEvent, Error>
}
```

### TargetType Protocol

Define your API endpoints:

```swift
public protocol TargetType {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: [String: String]? { get }
}
```

### NetworkTask

Request configuration options:

- `requestPlain` - No parameters
- `requestData(Data)` - Raw data body
- `requestJSONEncodable(Encodable)` - JSON-encoded body
- `requestParameters(parameters:encoding:)` - Parameters with encoding strategy

### PluginType Protocol

Middleware system:

```swift
public protocol PluginType {
    func prepare(_ request: URLRequest, target: TargetType) async -> URLRequest
    func willSend(_ request: URLRequest, target: TargetType)
    func didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType)
}
```

### SSEEvent

Server-Sent Events data structure:

```swift
public struct SSEEvent {
    public let id: String?
    public let event: String?
    public let data: String?
    public let retry: String?
}
```

## Building and Testing

```bash
# Build the package
swift build

# Build for release
swift build -c release

# Run tests (when available)
swift test

# Generate Xcode project
swift package generate-xcodeproj
```

## License

[Add your license here]

## Contributing

[Add contributing guidelines here]