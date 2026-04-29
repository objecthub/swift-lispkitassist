//
//  ToolRegistry.swift
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

/// Keeps track of all tools the assistant is allowed to invoke.
/// Thread-safety is intentionally simple: register all tools before
/// handing the registry to the engine.
public final class ToolRegistry: Sendable {
  
  /// All registered tools.
  public let tools: [any AssistantTool]
  
  public init(tools: [any AssistantTool] = []) {
    self.tools = tools
  }
  
  /// Find a tool by name.
  public func tool(named name: String) -> (any AssistantTool)? {
    return self.tools.first { $0.name == name }
  }
  
  /// Execute the named tool with the given input.
  /// Throws `ToolError.toolNotFound` if no matching tool is registered.
  public func execute(toolName: String, input: [String: JSON]) async throws -> String {
    guard let tool = self.tool(named: toolName) else {
      throw ToolError.toolNotFound(toolName)
    }
    return try await tool.execute(input: input)
  }
  
  /// Encode all tools in the format expected by the Anthropic API.
  var apiTools: [APITool] {
    return self.tools.map(\.apiRepresentation)
  }
  
  /// Create a new registry that includes `tool` appended.
  func adding(_ tool: any AssistantTool...) -> ToolRegistry {
    return ToolRegistry(tools: tools + tool)
  }
}
