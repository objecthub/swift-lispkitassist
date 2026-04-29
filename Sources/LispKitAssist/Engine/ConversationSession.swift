//
//  ConversationSession.swift
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

/// Holds the ordered history of messages for one conversation.
///
/// This class is not `Sendable` intentionally — the engine owns and
/// mutates it serially; it should not be shared across tasks.
public final class ConversationSession {
  
  /// The full message history in chronological order.
  public private(set) var messages: [Message] = []
  
  public init(messages: [Message] = []) {
    self.messages = messages
  }
  
  /// Append a message to the history.
  public func append(_ message: Message) {
    messages.append(message)
  }
  
  /// Convenience: append a plain user message.
  public func appendUserText(_ text: String) {
    append(.user(text))
  }
  
  /// Remove all messages, starting a fresh conversation.
  public func reset() {
    messages.removeAll()
  }
  
  /// The last assistant response, if any.
  public var lastAssistantMessage: Message? {
    messages.last { $0.role == .assistant }
  }
  
  /// All messages formatted for the Anthropic API.
  var apiMessages: [APIMessage] {
    messages.map(\.apiRepresentation)
  }
}
