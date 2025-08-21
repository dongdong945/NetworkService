# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Technology Stack

This is a Swift Package Manager (SPM) based networking library written in Swift 5.5+. It targets modern Apple platforms (macOS 12.0+, iOS 15.0+, tvOS 15.0+, watchOS 8.0+) and has zero external dependencies, using only Foundation framework.

## Project Structure

```
NetworkService/
├── Package.swift                      # SPM package configuration
├── CLAUDE.md                         # This guidance file
└── Sources/
    └── NetworkService/
        ├── NetworkService.swift       # Core networking client with SSE support
        ├── TargetType.swift          # API endpoint definition protocol
        └── PluginType.swift          # Plugin/middleware system
```

## Common Commands

```bash
# Build the package
swift build

# Run all tests (if tests exist)
swift test

# Build for release
swift build -c release

# Generate Xcode project if needed
swift package generate-xcodeproj
```

## Architecture Overview

The library follows a protocol-oriented design with three core abstractions:

1. **`TargetType`**: Protocol for defining API endpoints with baseURL, path, method, task, and headers
2. **`NetworkService`**: Main networking client that executes requests and handles SSE streams
3. **`PluginType`**: Middleware system for request/response interception with async support

### Key Components

#### NetworkService (Sources/NetworkService/NetworkService.swift)
Core networking client with two main methods:
- `request(_ target: TargetType) async throws -> Data` - Standard HTTP requests using URLSession
- `sse(_ target: TargetType) -> AsyncThrowingStream<SSEEvent, Error>` - Server-Sent Events streaming

The service includes plugin support with lifecycle hooks:
- `prepare(_:target:)` - Async request preparation
- `willSend(_:target:)` - Pre-request notification
- `didReceive(_:target:)` - Post-response handling

#### TargetType Protocol (Sources/NetworkService/TargetType.swift)
Defines API endpoints with required properties:
- `baseURL: URL` - Base URL for the API
- `path: String` - Endpoint path
- `method: HTTPMethod` - HTTP method (GET, POST, PUT, DELETE, PATCH)
- `task: NetworkTask` - Request configuration
- `headers: [String: String]?` - Optional headers

#### NetworkTask Enum
Type-safe request configuration:
- `requestPlain` - No parameters
- `requestData(Data)` - Raw data body
- `requestJSONEncodable(Encodable)` - JSON-encoded body with automatic Content-Type
- `requestParameters(parameters:encoding:)` - Parameter encoding with strategy

#### Parameter Encoding
- `URLEncoding` - Query string parameters
- `JSONEncoding` - JSON body encoding with Content-Type header

#### PluginType Protocol (Sources/NetworkService/PluginType.swift)
Middleware system with default implementations:
- `prepare(_ request: URLRequest, target: TargetType) async -> URLRequest` - Async request modification
- `willSend(_ request: URLRequest, target: TargetType)` - Pre-send hook
- `didReceive(_ result: Result<(response: URLResponse, data: Data), Error>, target: TargetType)` - Post-response hook

### Server-Sent Events (SSE)

Custom SSE implementation with:
- **SSEEvent struct**: Contains id, event, data, and retry fields
- **SSEParser class**: Internal parser handling SSE protocol specification
- **AsyncThrowingStream**: Modern Swift concurrency for streaming events
- **Buffer management**: Proper handling of partial data and event boundaries

Key features:
- Handles multi-line data fields
- Supports event types and IDs
- Manages reconnection retry timing
- Proper comment line handling (lines starting with ':')

## Code Patterns

- **Modern Swift Concurrency**: Uses `async/await` throughout, no completion handlers
- **Protocol-Oriented Design**: Extensible through protocols with default implementations
- **Type Safety**: Enum-based API definitions prevent runtime errors
- **Zero Dependencies**: Only uses Foundation framework
- **Sendable Compliance**: Thread-safe design with `@unchecked Sendable` where needed
- **Plugin Architecture**: Composable middleware system for cross-cutting concerns

## Testing

Currently no test suite is present in the project structure. When adding tests, consider:
- Swift Testing framework (recommended for new Swift projects)
- Unit tests for individual components
- Integration tests for network functionality
- Mock implementations for offline testing