//
//  Message.swift
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

/// A single block of content within a message.
/// This is the *domain* representation; the API wire format is in `APIModels.swift`.
public enum ContentItem: Sendable {
  /// A plain-text fragment produced by the model or written by the user.
  case text(String)
  
  /// A tool-invocation request emitted by the assistant.
  case toolUse(id: String, name: String, input: [String: JSON])
  
  /// The result of executing a tool, sent back to the model.
  case toolResult(toolUseId: String, content: String, isError: Bool)
}

/// A conversation turn: either user input or assistant output.
public struct Message: Sendable {
  public enum Role: String, Codable, Sendable {
    case user
    case assistant
  }
  
  public let role: Role
  
  public let content: [ContentItem]
  
  public init(role: Role, content: [ContentItem]) {
    self.role = role
    self.content = content
  }
  
  /// Create a plain user-text message.
  public static func user(_ text: String) -> Message {
    return Message(role: .user, content: [.text(text)])
  }
  
  /// Create a plain assistant-text message.
  public static func assistant(_ text: String) -> Message {
    return Message(role: .assistant, content: [.text(text)])
  }
  
  /// The concatenation of all `.text` content items.
  public var textContent: String {
    return content.compactMap {
      if case .text(let t) = $0 { return t }
      return nil
    }.joined()
  }
  
  /// All tool-use blocks in this message.
  public var toolUseCalls: [(id: String, name: String, input: [String: JSON])] {
    content.compactMap {
      if case .toolUse(let id, let name, let input) = $0 {
        return (id: id, name: name, input: input)
      }
      return nil
    }
  }
  
  /// Convert to the API wire format for inclusion in a request body.
  var apiRepresentation: APIMessage {
    let blocks: [APIContentBlock] = content.map { item in
      switch item {
        case .text(let text):
          return .text(text)
        case .toolUse(let id, let name, let input):
          return .toolUse(id: id, name: name, input: input)
        case .toolResult(let toolUseId, let content, let isError):
          return .toolResult(toolUseId: toolUseId, content: content, isError: isError)
      }
    }
    return APIMessage(role: role.rawValue, content: blocks)
  }
}
