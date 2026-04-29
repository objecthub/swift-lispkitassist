//
//  StreamParser.swift
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

/// Decoded events produced while consuming an Anthropic SSE stream.
public enum StreamEvent: Sendable {
  /// A chunk of model-generated text.
  case textDelta(String)
  
  /// The model is starting a tool call at the given content-block index.
  case toolUseStart(index: Int, id: String, name: String)
  
  /// An incremental JSON fragment for a tool's input.
  case toolInputDelta(index: Int, partialJson: String)
  
  /// A content block has ended.
  case contentBlockStop(index: Int)
  
  /// The message is wrapping up; carries the stop reason.
  case messageDelta(stopReason: String?)
  
  /// The stream is finished.
  case messageStop
  
  /// A keep-alive ping — safe to ignore.
  case ping
}

/// Stateless parser that converts raw SSE `data:` payloads into `StreamEvent` values.
public struct StreamParser {
  private static let decoder = JSONDecoder()
  
  private init() {}
  
  /// Parse one SSE data payload.  Returns `nil` for events we don't care about.
  public static func parse(data: Data) -> StreamEvent? {
    guard let base = try? decoder.decode(SSEBaseEvent.self, from: data) else {
      return nil
    }
    
    switch base.type {
      case "ping":
        return .ping
        
      case "content_block_start":
        guard let event = try? decoder.decode(SSEContentBlockStartEvent.self, from: data) else {
          return nil
        }
        let block = event.contentBlock
        if block.type == "tool_use", let id = block.id, let name = block.name {
          return .toolUseStart(index: event.index, id: id, name: name)
        }
          // text block start carries no useful incremental data
        return nil
        
      case "content_block_delta":
        guard let event = try? decoder.decode(SSEContentBlockDeltaEvent.self, from: data) else {
          return nil
        }
        switch event.delta.type {
          case "text_delta":
            return .textDelta(event.delta.text ?? "")
          case "input_json_delta":
            return .toolInputDelta(index: event.index, partialJson: event.delta.partialJson ?? "")
          default:
            return nil
        }
        
      case "content_block_stop":
        guard let event = try? decoder.decode(SSEContentBlockStopEvent.self, from: data) else {
          return nil
        }
        return .contentBlockStop(index: event.index)
        
      case "message_delta":
        guard let event = try? decoder.decode(SSEMessageDeltaEvent.self, from: data) else {
          return nil
        }
        return .messageDelta(stopReason: event.delta.stopReason)
        
      case "message_stop":
        return .messageStop
        
      default:
        return nil
    }
  }
}
