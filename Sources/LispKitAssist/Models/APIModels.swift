//
//  APIModels.swift
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

/// The top-level body sent to POST /v1/messages.
struct MessageRequest: Encodable {
  let model: String
  let maxTokens: Int
  let system: String?
  let messages: [APIMessage]
  let tools: [APITool]?
  let stream: Bool
  
  enum CodingKeys: String, CodingKey {
    case model, system, messages, tools, stream
    case maxTokens = "max_tokens"
  }
}

/// A single turn in the messages array.
struct APIMessage: Encodable {
  let role: String
  let content: [APIContentBlock]
}

/// A content block inside a message — text, tool-use, or tool-result.
enum APIContentBlock: Encodable {
  case text(String)
  case toolUse(id: String, name: String, input: [String: JSON])
  case toolResult(toolUseId: String, content: String, isError: Bool)
  
  private enum CodingKeys: String, CodingKey {
    case type, text, id, name, input, content
    case toolUseId = "tool_use_id"
    case isError   = "is_error"
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
      case .text(let text):
        try container.encode("text", forKey: .type)
        try container.encode(text,   forKey: .text)
        
      case .toolUse(let id, let name, let input):
        try container.encode("tool_use", forKey: .type)
        try container.encode(id,          forKey: .id)
        try container.encode(name,        forKey: .name)
        try container.encode(input,       forKey: .input)
        
      case .toolResult(let toolUseId, let content, let isError):
        try container.encode("tool_result", forKey: .type)
        try container.encode(toolUseId,     forKey: .toolUseId)
        try container.encode(content,       forKey: .content)
        if isError {
          try container.encode(isError,   forKey: .isError)
        }
    }
  }
}

/// Describes a tool the model is allowed to call.
struct APITool: Encodable {
  let name: String
  let description: String
  let inputSchema: JSON
  
  enum CodingKeys: String, CodingKey {
    case name, description
    case inputSchema = "input_schema"
  }
}

// These are used internally by StreamParser.

struct SSEBaseEvent: Decodable {
  let type: String
}

struct SSEContentBlockStartEvent: Decodable {
  let index: Int
  let contentBlock: ContentBlockPayload
  
  enum CodingKeys: String, CodingKey {
    case index
    case contentBlock = "content_block"
  }
  
  struct ContentBlockPayload: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
  }
}

struct SSEContentBlockDeltaEvent: Decodable {
  let index: Int
  let delta: Delta
  
  struct Delta: Decodable {
    let type: String
    let text: String?
    let partialJson: String?
    
    enum CodingKeys: String, CodingKey {
      case type, text
      case partialJson = "partial_json"
    }
  }
}

struct SSEContentBlockStopEvent: Decodable {
  let index: Int
}

struct SSEMessageDeltaEvent: Decodable {
  let delta: Delta
  
  struct Delta: Decodable {
    let stopReason: String?
    
    enum CodingKeys: String, CodingKey {
      case stopReason = "stop_reason"
    }
  }
}
