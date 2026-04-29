//
//  DocumentationTool.swift
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

/// A tool that searches the LispKit Scheme documentation files on disk
/// and returns the matching markdown content to the model.
///
/// The documentation directory is expected to contain `.md` files whose
/// names follow the LispKit convention: `(lispkit <library>).md`.
public final class DocumentationTool: AssistantTool {
  
  public let name = "lookup_lispkit_documentation"
  
  public let description = """
      Look up official LispKit documentation for a library or built-in function.
      Provide a query such as a library name (e.g. "lispkit list", "lispkit hashtable")
      or a procedure name (e.g. "fold-left", "string-split").
      Returns the full markdown documentation for the best matching library.
      Use this tool whenever you need precise function signatures or examples.
    """
  
  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "query": .object([
          "type": .string("string"),
          "description": .string(
            "A library name (e.g. \"lispkit list\") or procedure name to search for."
          )
        ])
      ]),
      "required": .array([.string("query")])
    ])
  }
  
  private let documentationDirectory: URL
  
  /// - Parameter documentationDirectory: Path to the folder containing
  ///   the LispKit markdown documentation files.
  public init(documentationDirectory: URL) {
    self.documentationDirectory = documentationDirectory
  }
  
  public func execute(input: [String: JSON]) async throws -> String {
    guard let queryValue = input["query"],
          case .string(let query) = queryValue,
          !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw ToolError.invalidInput("'query' must be a non-empty string.")
    }
    let files = try discoverDocumentationFiles()
    let results = rank(files: files, for: query)
    if let best = results.first {
      let content = try String(contentsOf: best.url, encoding: .utf8)
      return "# \(best.displayName)\n\n\(content)"
    }
    // No match — return the list of available libraries
    let available = files
      .map(\.displayName)
      .sorted()
      .joined(separator: "\n• ")
    return """
      No documentation matched '\(query)'.
      
      Available LispKit libraries:
      • \(available)
      
      Try a more general term, e.g. "lispkit list" instead of "append".
    """
  }
  
  private struct DocFile {
    let url: URL
    let displayName: String   // filename without extension, e.g. "(lispkit list)"
    let searchTokens: [String] // lowercased words for ranking
  }
  
  private func discoverDocumentationFiles() throws -> [DocFile] {
    let manager = FileManager.default
    let contents = try manager.contentsOfDirectory(
      at: documentationDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    return contents
      .filter { $0.pathExtension.lowercased() == "md" }
      .map { url in
        let display = url.deletingPathExtension().lastPathComponent
        let tokens  = display
          .lowercased()
          .components(separatedBy: CharacterSet.alphanumerics.inverted)
          .filter { !$0.isEmpty }
        return DocFile(url: url, displayName: display, searchTokens: tokens)
      }
  }
  
  /// Score each file against the query and return them sorted best-first.
  private func rank(files: [DocFile], for query: String) -> [DocFile] {
    let queryTokens = query
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
    let scored: [(file: DocFile, score: Int)] = files.compactMap { file in
      var score = 0
      // Check filename match
      let displayLower = file.displayName.lowercased()
      let queryLower   = query.lowercased()
      if displayLower == queryLower {
        score += 100
      }
      if displayLower.contains(queryLower) {
        score += 50
      }
      for token in queryTokens where displayLower.contains(token) {
        score += 10
      }
      // Token-level match
      for qToken in queryTokens {
        for fToken in file.searchTokens where fToken == qToken { score += 5 }
        for fToken in file.searchTokens where fToken.hasPrefix(qToken) { score += 2 }
      }
      return score > 0 ? (file, score) : nil
    }
    
    return scored
      .sorted { $0.score > $1.score }
      .map(\.file)
  }
}
