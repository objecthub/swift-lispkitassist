//
//  CLIPresenter.swift
//  LispKitCLI
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
import LispKitAssist

private enum ANSI {
  static let reset     = "\u{001B}[0m"
  static let bold      = "\u{001B}[1m"
  static let dim       = "\u{001B}[2m"
  static let cyan      = "\u{001B}[36m"
  static let green     = "\u{001B}[32m"
  static let yellow    = "\u{001B}[33m"
  static let red       = "\u{001B}[31m"
  static let magenta   = "\u{001B}[35m"
  static let blue      = "\u{001B}[34m"
  static let white     = "\u{001B}[97m"
  
  static func color(_ code: String, _ text: String) -> String {
    "\(code)\(text)\(reset)"
  }
}

/// Renders `AssistantEngineDelegate` events to the terminal.
///
/// This class is the **only** place where `print` and `readLine` are called.
/// Swap it for a SwiftUI `@Observable` view model to build a graphical UI.
public final class CLIPresenter: AssistantEngineDelegate {
  private var responseStarted = false
  private var lastTokenWasNewline = false
  private var needsAssistantHeader = false
  
  /// Display the interactive prompt and return the trimmed user input.
  /// Returns `nil` when EOF is reached (Ctrl-D).
  public func readUserInput() -> String? {
    print("\n\(ANSI.color(ANSI.bold + ANSI.cyan, "you")) \(ANSI.color(ANSI.dim, "›"))", terminator: " ")
    fflush(stdout)
    guard let line = readLine(strippingNewline: true) else { return nil }
    return line.trimmingCharacters(in: .whitespaces)
  }
  
  public func printWelcome() {
    let banner = """
            
            ╔══════════════════════════════════════════╗
            ║        LispKit Assist  •  Claude         ║
            ║   Scheme coding assistant for LispKit    ║
            ╚══════════════════════════════════════════╝
            """
    print(ANSI.color(ANSI.cyan + ANSI.bold, banner))
    print(ANSI.color(ANSI.dim,
                     "  Type your question or Scheme code.  " +
                     "Commands: /reset  /quit\n"))
  }
  
  public func printGoodbye() {
    print("\n\(ANSI.color(ANSI.dim, "Goodbye! Happy hacking in Scheme."))\n")
  }
  
  public func printInfo(_ text: String) {
    print(ANSI.color(ANSI.dim, "  \(text)"))
  }
  
  public func printSuccess(_ text: String) {
    print(ANSI.color(ANSI.green, "  ✓ \(text)"))
  }
  
  public func printError(_ text: String) {
    print(ANSI.color(ANSI.red, "  ✗ \(text)"))
  }
  
  public func engineDidStartResponding() {
    responseStarted = false
    lastTokenWasNewline = false
    needsAssistantHeader = false
    print("\n\(ANSI.color(ANSI.bold + ANSI.magenta, "assistant")) \(ANSI.color(ANSI.dim, "›"))", terminator: " ")
    fflush(stdout)
  }

  public func engineDidReceiveToken(_ token: String) {
    if needsAssistantHeader {
      print("\(ANSI.color(ANSI.bold + ANSI.magenta, "assistant")) \(ANSI.color(ANSI.dim, "›"))", terminator: " ")
      needsAssistantHeader = false
    }
    print(token, terminator: "")
    fflush(stdout)
    responseStarted = true
    lastTokenWasNewline = token.hasSuffix("\n")
  }

  public func engineDidStartToolCall(id: String, name: String) {
    // A new tool call supersedes any pending header
    needsAssistantHeader = false
    if !lastTokenWasNewline {
      print()
    }
    print(ANSI.color(ANSI.dim + ANSI.yellow, "  ⚙  calling tool: \(name) …"))
    fflush(stdout)
    lastTokenWasNewline = true
  }

  public func engineDidFinishToolCall(id: String, name: String, result: String, isError: Bool) {
    let icon = isError ? "✗" : "✓"
    let colour = isError ? ANSI.red : ANSI.dim
    print(ANSI.color(colour, "  \(icon)  \(name) complete"))
    fflush(stdout)
    lastTokenWasNewline = true
    // If the model continues with text after this tool result, show the header then
    needsAssistantHeader = true
  }
  
  public func engineDidFinishResponding(message: Message) {
    if !lastTokenWasNewline {
      print()
    }
    print(ANSI.color(ANSI.dim, "  ─────────────────────────────"))
  }
  
  public func engineDidEncounterError(_ error: Error) {
    print()
    printError(error.localizedDescription)
  }
}
