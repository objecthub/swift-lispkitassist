//
//  AssistantTool.swift
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
import DynamicJSON

/// A capability that the assistant can invoke during a conversation.
///
/// Adopt this protocol to create custom tools — e.g. a Scheme REPL,
/// a file reader, or an internet search.  The engine will register
/// tools with the Anthropic API and dispatch calls automatically.
public protocol AssistantTool: Sendable {
  /// The identifier the model uses to call this tool.
  /// Must be unique within the registry and match `[a-zA-Z0-9_-]+`.
  var name: String { get }
  
  /// Human-readable description passed to the model so it knows when to use the tool.
  var description: String { get }
  
  /// JSON Schema (as a `JSONValue`) describing the tool's `input` object.
  /// Must be a `.object` with at least a `"type": "object"` field.
  var inputSchema: JSON { get }
  
  /// Execute the tool with the validated input dictionary.
  /// Return a plain-text result string; errors should be thrown.
  func execute(input: [String: JSON]) async throws -> String
}

extension AssistantTool {
  /// Convert to the Anthropic API tool-definition format.
  var apiRepresentation: APITool {
    APITool(name: name, description: description, inputSchema: inputSchema)
  }
}

public enum ToolError: Error, LocalizedError {
  case toolNotFound(String)
  case invalidInput(String)
  case executionFailed(String)
  
  public var errorDescription: String? {
    switch self {
      case .toolNotFound(let name):    return "Tool not found: \(name)"
      case .invalidInput(let msg):     return "Invalid tool input: \(msg)"
      case .executionFailed(let msg):  return "Tool execution failed: \(msg)"
    }
  }
}
