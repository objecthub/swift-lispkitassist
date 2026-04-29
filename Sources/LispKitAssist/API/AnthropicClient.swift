//
//  AnthropicClient.swift
//  LispKitAssist
//
//  Created by Matthias Zenger on 29/04/2026.
//  Copyright © 2026 ObjectHub. All rights reserved.
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// All settings needed to talk to the Anthropic Messages API.
public struct AnthropicConfiguration: Sendable {
  public var apiKey: String
  public var model: String
  public var maxTokens: Int
  public var baseURL: String
  
  public init(
    apiKey: String,
    model: String  = "claude-opus-4-6",
    maxTokens: Int = 8192,
    baseURL: String = "https://api.anthropic.com"
  ) {
    self.apiKey    = apiKey
    self.model     = model
    self.maxTokens = maxTokens
    self.baseURL   = baseURL
  }
}

public enum AnthropicError: Error, LocalizedError {
  case invalidURL
  case missingAPIKey
  case httpError(statusCode: Int, body: String)
  case streamDecodingError(String)
  case networkError(Error)
  
  public var errorDescription: String? {
    switch self {
      case .invalidURL:
        return "The Anthropic API URL is malformed."
      case .missingAPIKey:
        return "No Anthropic API key found. Run `lispkit-assist --set-key` to configure it."
      case .httpError(let code, let body):
        return "HTTP \(code): \(body)"
      case .streamDecodingError(let msg):
        return "Stream decoding error: \(msg)"
      case .networkError(let underlying):
        return "Network error: \(underlying.localizedDescription)"
    }
  }
}

/// Low-level HTTP client for the Anthropic Messages API.
/// Streams SSE events as an `AsyncThrowingStream<StreamEvent, Error>`.
/// This type is deliberately slim — no conversation state, no tool logic.
public final class AnthropicClient: Sendable {
  
  private let configuration: AnthropicConfiguration
  private let urlSession: URLSession
  
  public init(configuration: AnthropicConfiguration) {
    self.configuration = configuration
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest  = 120
    sessionConfig.timeoutIntervalForResource = 600
    self.urlSession = URLSession(configuration: sessionConfig)
  }
  
  /// Open a streaming conversation request and yield decoded `StreamEvent` values.
  /// The caller is responsible for building the full messages array including any
  /// tool-result turns.
  // Internal: takes wire-format types that are intentionally not public API.
  // External callers go through AssistantEngine.sendMessage(_:).
  func streamMessages(messages: [APIMessage],
                      system: String?,
                      tools: [APITool] = []) -> AsyncThrowingStream<StreamEvent, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let request = try self.buildRequest(
            messages: messages,
            system: system,
            tools: tools
          )
          let (bytes, response) = try await self.urlSession.bytes(for: request)
          guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.networkError(URLError(.badServerResponse))
          }
          guard (200..<300).contains(httpResponse.statusCode) else {
              // Collect the error body before throwing
            var errorBody = ""
            for try await byte in bytes {
              errorBody.append(Character(UnicodeScalar(byte)))
            }
            throw AnthropicError.httpError(
              statusCode: httpResponse.statusCode,
              body: errorBody
            )
          }
          // Parse SSE lines
          for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
              let payload = String(line.dropFirst(6))
              guard payload != "[DONE]",
                    let data = payload.data(using: .utf8)
              else { continue }
              
              if let event = StreamParser.parse(data: data) {
                continuation.yield(event)
                if case .messageStop = event { break }
              }
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
  
  private func buildRequest(messages: [APIMessage],
                            system: String?,
                            tools: [APITool]) throws -> URLRequest {
    guard !configuration.apiKey.isEmpty else {
      throw AnthropicError.missingAPIKey
    }
    guard let url = URL(string: "\(configuration.baseURL)/v1/messages") else {
      throw AnthropicError.invalidURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    let body = MessageRequest(
      model:     configuration.model,
      maxTokens: configuration.maxTokens,
      system:    system,
      messages:  messages,
      tools:     tools.isEmpty ? nil : tools,
      stream:    true
    )
    let encoder = JSONEncoder()
    request.httpBody = try encoder.encode(body)
    return request
  }
}
