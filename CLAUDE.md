# CLAUDE.md — LispKit Assist

## Project Overview

LispKitAssist is a Swift framework and CLI tool for AI-assisted LispKit Scheme development. It integrates with the Anthropic Claude API to provide a conversational coding assistant with streaming responses, tool use, and bundled LispKit documentation search.

## Build & Run

```bash
# Build the project
swift build

# Run the CLI tool
swift run LispKitCLI

# Run tests
swift test

# Set API key (stored in macOS Keychain)
swift run LispKitCLI --set-key

# Delete stored API key
swift run LispKitCLI --delete-key
```

**Requirements**: macOS 13.0+, Swift 5.9+ (tested with Swift 6.3.1, Apple Silicon)

The project uses Swift Package Manager. An Xcode project (`LispKitAssist.xcodeproj`) is also available for IDE development.

## Project Structure

```
Sources/
  LispKitAssist/                # Framework (public API)
    API/                        # AnthropicClient, StreamParser (HTTP + SSE streaming)
      AnthropicClient.swift     # URLSession-based streaming client; yields AsyncThrowingStream<StreamEvent>
      StreamParser.swift        # SSE event parser (text deltas, tool-use blocks, stop reasons)
    Engine/                     # AssistantEngine, ConversationSession, SystemPromptBuilder
      AssistantEngine.swift     # The agentic loop: stream → tool-call cycle → final response
      AssistantDelegate.swift   # Protocol with default no-ops — implement only what your UI needs
      ConversationSession.swift # Ordered message history; converts to API format
      SystemPromptBuilder.swift # LispKit-aware system prompt; inject per-session context via extraContext
    Models/                     # APIModels, Message (domain types)
      APIModels.swift           # Anthropic wire-format Encodable/Decodable structs
      Message.swift             # Domain Message / ContentItem types
    Tools/                      # AssistantTool protocol, ToolRegistry, DocumentationTool
      AssistantTool.swift       # Protocol + ToolError enum every tool must implement
      DocumentationTool.swift   # Searches Resources/Documentation/ and returns ranked Markdown results
      ToolRegistry.swift        # Immutable registry; dispatch to the right tool by name
  LispKitCLI/                   # CLI executable
    main.swift                  # Entry point
    CLIPresenter.swift          # Terminal UI (implements AssistantEngineDelegate)
    KeychainManager.swift       # macOS Keychain integration
Tests/
  LispKitAssistTests/           # Swift Testing framework
Resources/
  Documentation/                # 80+ LispKit library docs (markdown), consumed at runtime
  Examples/                     # Scheme test files, libraries, programs
```

## Architecture

- **Layered design**: Presentation (CLI) → Engine → Tools → API → Models
- **Delegate pattern**: `AssistantEngineDelegate` decouples engine from UI (enables CLI or SwiftUI)
- **Protocol-based tool system**: `AssistantTool` protocol for extensible capabilities
- **Agentic loop**: Engine streams responses, detects tool calls, executes tools, feeds results back until the model stops requesting tools
- **Streaming**: `AsyncThrowingStream<StreamEvent, Error>` for SSE event delivery

## Dependencies

- `swift-commandlinekit` (>= 1.0.0) — CLI argument parsing
- `swift-dynamicjson` (main branch) — Dynamic JSON handling for API models
- `Security` framework (macOS) — Keychain access

## Coding Conventions

- **Indentation**: 2 spaces
- **Bracket style**: K&R (opening brace on same line)
- **Access control**: `public` for framework APIs, `internal`/`private` for implementation
- **Classes**: Marked `final` unless inheritance is intended
- **One primary type per file**, grouped in logical folders
- **Naming**: PascalCase for types/protocols, camelCase for methods/properties/constants
- **Concurrency**: async/await throughout; `Sendable` conformance where appropriate; intentionally non-Sendable types for serial mutation (e.g., `ConversationSession`)
- **Error handling**: Typed error enums conforming to `LocalizedError`; prefer `guard` and `throws` over force unwraps
- **No linter configured** (no SwiftLint or similar)
- **Testing framework**: Apple's Swift Testing (`@Test`, `#expect`)

## Key Types

| Type | Role |
|------|------|
| `AssistantEngine` | Orchestrates multi-turn conversations with agentic loop |
| `AnthropicClient` | HTTP client with SSE streaming for Claude API |
| `ConversationSession` | Message history and API format conversion |
| `SystemPromptBuilder` | Dynamic system prompt construction |
| `AssistantTool` (protocol) | Interface for registering executable tools |
| `ToolRegistry` | Manages tool lifecycle and execution |
| `DocumentationTool` | Token-based search over bundled LispKit docs |
| `AssistantEngineDelegate` (protocol) | Callback interface for streaming events |
| `CLIPresenter` | Terminal rendering, implements delegate |
| `KeychainManager` | macOS Keychain CRUD for API credentials |

## API Key Handling

The CLI checks for an API key in this order:
1. macOS Keychain (stored via `--set-key`)
2. `ANTHROPIC_API_KEY` environment variable

Never hardcode API keys. The framework's `AnthropicConfiguration` accepts the key at initialization.
