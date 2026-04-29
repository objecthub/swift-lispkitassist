//
//  main.swift
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

// Swift async CLI pattern: schedule work on the main actor and drive
// the event loop so async tasks can complete.
Task { @MainActor in
  let app = CLIApplication()
  let code = await app.run()
  exit(code)
}
RunLoop.main.run()

final class CLIApplication {
  
  private let keychain  = KeychainManager()
  private let presenter = CLIPresenter()
  
  func run() async -> Int32 {
    let args = CommandLine.arguments.dropFirst()
    
    if args.contains("--set-key")    { return setAPIKeyInteractively() }
    if args.contains("--delete-key") { return deleteAPIKey() }
    if args.contains("--help") || args.contains("-h") { printHelp(); return 0 }
    
    return await runREPL()
  }
  
  private func runREPL() async -> Int32 {
    guard let apiKey = loadAPIKey() else { return 1 }
    
    let config = AnthropicConfiguration(apiKey: apiKey)
    
      // Register the documentation tool if the docs directory is present
    var tools: [any AssistantTool] = []
    if let docsURL = resolveDocumentationDirectory() {
      tools.append(DocumentationTool(documentationDirectory: docsURL))
      presenter.printInfo("Documentation loaded from: \(docsURL.path)")
    } else {
      presenter.printInfo("No LispKit documentation found (tool disabled).")
    }
    
    let registry = ToolRegistry(tools: tools)
    let engine   = AssistantEngine(configuration: config, toolRegistry: registry)
    engine.delegate = presenter
    
    presenter.printWelcome()
    
    while true {
      guard let input = presenter.readUserInput() else {
        presenter.printGoodbye()
        return 0
      }
      
      guard !input.isEmpty else { continue }
      
      switch input {
        case "/quit", "/exit", ":q":
          presenter.printGoodbye()
          return 0
          
        case "/reset":
          engine.resetConversation()
          presenter.printInfo("Conversation reset.")
          
        case "/help":
          printREPLHelp()
          
        default:
          await engine.sendMessage(input)
      }
    }
  }
  
  private func loadAPIKey() -> String? {
    if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
       !envKey.isEmpty {
      return envKey
    }
    do {
      if let key = try keychain.loadAPIKey() { return key }
    } catch {
      presenter.printError("Keychain error: \(error.localizedDescription)")
      return nil
    }
    presenter.printError("No Anthropic API key found.")
    presenter.printInfo("Run:  lispkit-assist --set-key")
    presenter.printInfo("  or export ANTHROPIC_API_KEY=<key>")
    return nil
  }
  
  private func setAPIKeyInteractively() -> Int32 {
    print("Enter your Anthropic API key (input is hidden): ", terminator: "")
    fflush(stdout)
    
      // Temporarily disable terminal echo so the key isn't visible
    var saved = termios()
    tcgetattr(STDIN_FILENO, &saved)
    var silent = saved
    silent.c_lflag &= ~tcflag_t(ECHO)
    tcsetattr(STDIN_FILENO, TCSANOW, &silent)
    let key = readLine(strippingNewline: true) ?? ""
    tcsetattr(STDIN_FILENO, TCSANOW, &saved)
    print()   // newline after hidden input
    
    guard !key.trimmingCharacters(in: .whitespaces).isEmpty else {
      presenter.printError("API key cannot be empty.")
      return 1
    }
    do {
      try keychain.saveAPIKey(key)
      presenter.printSuccess("API key saved to Keychain.")
      return 0
    } catch {
      presenter.printError("Failed to save key: \(error.localizedDescription)")
      return 1
    }
  }
  
  private func deleteAPIKey() -> Int32 {
    do {
      try keychain.deleteAPIKey()
      presenter.printSuccess("API key removed from Keychain.")
      return 0
    } catch {
      presenter.printError("Failed to remove key: \(error.localizedDescription)")
      return 1
    }
  }
  
  /// Search for the LispKit documentation directory, looking relative to the
  /// executable and then relative to the current working directory.
  private func resolveDocumentationDirectory() -> URL? {
    let candidates: [URL] = [
      URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/Documentation"),
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Resources/Documentation"),
    ]
    return candidates.first { url in
      var isDir: ObjCBool = false
      return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
             && isDir.boolValue
    }
  }
  
  private func printHelp() {
    print("""
            LispKit Assist — Scheme coding assistant powered by Claude
            
            USAGE
              lispkit-assist [OPTIONS]
            
            OPTIONS
              --set-key       Save your Anthropic API key to the macOS Keychain
              --delete-key    Remove the stored API key from the Keychain
              --help, -h      Show this help message
            
            ENVIRONMENT
              ANTHROPIC_API_KEY   Override the Keychain with an env variable
            
            REPL COMMANDS
              /reset   Clear the conversation history
              /quit    Exit
              /help    Show this list
              Ctrl-D   Exit
            """)
  }
  
  private func printREPLHelp() {
    presenter.printInfo("/reset  — new conversation  |  /quit  — exit  |  Ctrl-D  — exit")
  }
}
