//
//  AssistantDelegate.swift
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

/// Receive incremental progress events from `AssistantEngine`.
///
/// All methods have default no-op implementations so adopters can
/// implement only what they need.
///
/// **Threading:** Methods may be called from a background `Task`.
/// UI implementations (SwiftUI, AppKit) must dispatch updates to the
/// main actor, for example by making the conforming type `@MainActor`.
public protocol AssistantEngineDelegate: AnyObject {
  
  /// The engine has started processing the latest user message.
  func engineDidStartResponding()
  
  /// A new text token has arrived from the model.
  /// Call this to stream output character-by-character in the UI.
  func engineDidReceiveToken(_ token: String)
  
  /// The model has requested a tool call.
  func engineDidStartToolCall(id: String, name: String)
  
  /// A tool call completed.  `result` is the string the engine will
  /// feed back to the model.  `isError` is `true` if the tool threw.
  func engineDidFinishToolCall(id: String, name: String, result: String, isError: Bool)
  
  /// The model has finished generating its response for this turn.
  func engineDidFinishResponding(message: Message)
  
  /// An unrecoverable error occurred (network, API, etc.).
  func engineDidEncounterError(_ error: Error)
}

public extension AssistantEngineDelegate {
  func engineDidStartResponding() {}
  func engineDidReceiveToken(_ token: String) {}
  func engineDidStartToolCall(id: String, name: String) {}
  func engineDidFinishToolCall(id: String, name: String,
                               result: String, isError: Bool) {}
  func engineDidFinishResponding(message: Message) {}
  func engineDidEncounterError(_ error: Error) {}
}
