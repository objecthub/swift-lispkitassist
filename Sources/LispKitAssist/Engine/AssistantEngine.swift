//
//  AssistantEngine.swift
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

/// Orchestrates a multi-turn, tool-using conversation with Claude.
///
/// `AssistantEngine` owns the conversation session and drives the
/// agentic loop: send messages → stream response → execute tools →
/// repeat until the model signals `end_turn`.
///
/// **Separation of concerns**
/// - All presentation callbacks go through `AssistantEngineDelegate`.
/// - There is no `print` or UI code here, making it trivial to
///   swap the CLI presenter for a SwiftUI `@Observable` view model.
public final class AssistantEngine {
  
  public weak var delegate: (any AssistantEngineDelegate)?
  
  /// The live conversation history.
  public let session: ConversationSession
  
  private let client: AnthropicClient
  private let toolRegistry: ToolRegistry
  private let systemPromptBuilder: SystemPromptBuilder
  
  public init(configuration: AnthropicConfiguration,
              session: ConversationSession = ConversationSession(),
              toolRegistry: ToolRegistry = ToolRegistry(),
              systemPromptBuilder: SystemPromptBuilder = SystemPromptBuilder()) {
    self.client = AnthropicClient(configuration: configuration)
    self.session = session
    self.toolRegistry = toolRegistry
    self.systemPromptBuilder = systemPromptBuilder
  }
  
  /// Send a user message and run the agentic loop until the model
  /// produces a final response (which may involve multiple tool-use cycles).
  ///
  /// This method suspends until the full interaction is complete.
  public func sendMessage(_ text: String) async {
    session.appendUserText(text)
    await runAgentLoop()
  }
  
  /// Clear the conversation history, starting fresh.
  public func resetConversation() {
    session.reset()
  }
  
  private func runAgentLoop() async {
    delegate?.engineDidStartResponding()
    do {
      while true {
        // Accumulate one full assistant turn from the stream
        let turn = try await streamOneTurn()
        // Persist the assistant message
        session.append(turn.message)
        if turn.stopReason == "tool_use", !turn.toolCalls.isEmpty {
          // Execute every requested tool and collect results
          let resultItems = await executeToolCalls(turn.toolCalls)
          // Feed tool results back as a new user message and continue
          session.append(Message(role: .user, content: resultItems))
        } else {
          // The model is done; surface the final message
          delegate?.engineDidFinishResponding(message: turn.message)
          break
        }
      }
    } catch {
      delegate?.engineDidEncounterError(error)
    }
  }
  
  private struct TurnResult {
    let message: Message
    let toolCalls: [ToolCallAccumulator]
    let stopReason: String?
  }
  
  private func streamOneTurn() async throws -> TurnResult {
    let stream = client.streamMessages(messages: session.apiMessages,
                                       system: systemPromptBuilder.build(),
                                       tools: toolRegistry.apiTools)
    var textBuffer = ""
    var toolAccumulators: [Int: ToolCallAccumulator] = [:]
    var stopReason: String?
    for try await event in stream {
      switch event {
        case .textDelta(let token):
          textBuffer += token
          delegate?.engineDidReceiveToken(token)
        case .toolUseStart(let index, let id, let name):
          toolAccumulators[index] = ToolCallAccumulator(index: index, id: id, name: name)
          delegate?.engineDidStartToolCall(id: id, name: name)
        case .toolInputDelta(let index, let partialJson):
          toolAccumulators[index]?.inputJSON += partialJson
        case .messageDelta(let reason):
          stopReason = reason
        case .contentBlockStop, .messageStop, .ping:
          break
      }
    }
    // Build content items
    var content: [ContentItem] = []
    if !textBuffer.isEmpty {
      content.append(.text(textBuffer))
    }
    let completedToolCalls = toolAccumulators.values.sorted { $0.index < $1.index }
    for tc in completedToolCalls {
      let input = tc.parsedInput
      content.append(.toolUse(id: tc.id, name: tc.name, input: input))
    }
    let message = Message(role: .assistant, content: content)
    return TurnResult(message: message, toolCalls: completedToolCalls, stopReason: stopReason)
  }
  
  private func executeToolCalls(_ calls: [ToolCallAccumulator]) async -> [ContentItem] {
    var results: [ContentItem] = []
    for call in calls {
      do {
        let output = try await toolRegistry.execute(
          toolName: call.name,
          input: call.parsedInput
        )
        delegate?.engineDidFinishToolCall(id: call.id,
                                          name: call.name,
                                          result: output,
                                          isError: false)
        results.append(.toolResult(toolUseId: call.id, content: output, isError: false))
      } catch {
        let errMsg = error.localizedDescription
        delegate?.engineDidFinishToolCall(id: call.id,
                                          name: call.name,
                                          result: errMsg,
                                          isError: true)
        results.append(.toolResult(toolUseId: call.id, content: errMsg, isError: true))
      }
    }
    return results
  }
}

/// Collects streaming fragments for a single tool-use block.
struct ToolCallAccumulator {
  let index: Int
  let id: String
  let name: String
  var inputJSON: String = ""
  
  /// Attempt to decode the accumulated JSON; falls back to empty dictionary on failure.
  var parsedInput: [String: JSON] {
    let raw = inputJSON.isEmpty ? "{}" : inputJSON
    guard let data = raw.data(using: .utf8),
          let parsed = try? JSONDecoder().decode([String: JSON].self, from: data) else {
      return [:]
    }
    return parsed
  }
}
