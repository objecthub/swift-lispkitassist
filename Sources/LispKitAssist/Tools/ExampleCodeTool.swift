//
//  ExampleCodeTool.swift
//  LispKitAssist
//
//  Created by Matthias Zenger on 30/04/2026.
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

/// A tool that searches LispKit Scheme example programs and libraries on disk
/// and returns the matching source code to the model.
///
/// The examples directory is expected to contain `.scm` and `.sld` files
/// organized in subdirectories (e.g. `Programs/`, `Tests/`, `Libraries/`).
/// Library `.sld` files may be nested according to the library's name.
public final class ExampleCodeTool: AssistantTool {

  public let name = "search_example_code"

  public let description = """
      Search LispKit Scheme example programs and libraries for source code.
      Provide a query such as a program name (e.g. "queens", "maze", "blockchain"),
      a library name (e.g. "avl-tree", "simplifier"), or a topic (e.g. "coroutine",
      "draw", "http").
      Returns the full source code of the best matching example file.
      Use this tool to find idiomatic Scheme examples and coding patterns.
    """

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "query": .object([
          "type": .string("string"),
          "description": .string(
            "A program name, library name, or topic to search for in the examples."
          )
        ])
      ]),
      "required": .array([.string("query")])
    ])
  }

  private let examplesDirectory: URL

  /// - Parameter examplesDirectory: Path to the folder containing
  ///   the LispKit example programs and libraries.
  public init(examplesDirectory: URL) {
    self.examplesDirectory = examplesDirectory
  }

  public func execute(input: [String: JSON]) async throws -> String {
    guard let queryValue = input["query"],
          case .string(let query) = queryValue,
          !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw ToolError.invalidInput("'query' must be a non-empty string.")
    }
    let files = try discoverExampleFiles()
    let results = rank(files: files, for: query)
    if let best = results.first {
      let content = try String(contentsOf: best.url, encoding: .utf8)
      return "# \(best.displayName)\n# Path: \(best.relativePath)\n\n\(content)"
    }
    // No match — return the list of available examples
    let available = files
      .map(\.displayName)
      .sorted()
      .joined(separator: "\n• ")
    return """
      No example matched '\(query)'.

      Available examples:
      • \(available)

      Try a more general term, e.g. "queens" or "maze".
    """
  }

  private struct ExampleFile {
    let url: URL
    /// Human-readable name, e.g. "Queens" or "paip/simplifier"
    let displayName: String
    /// Path relative to the examples directory, e.g. "Programs/Queens.scm"
    let relativePath: String
    /// Lowercased tokens extracted from the relative path for ranking
    let searchTokens: [String]
  }

  private func discoverExampleFiles() throws -> [ExampleFile] {
    let manager = FileManager.default
    let extensions: Set<String> = ["scm", "sld"]
    guard let enumerator = manager.enumerator(
      at: examplesDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }
    var files: [ExampleFile] = []
    while let url = enumerator.nextObject() as? URL {
      guard extensions.contains(url.pathExtension.lowercased()) else { continue }
      let relativePath = url.path.hasPrefix(examplesDirectory.path)
        ? String(url.path.dropFirst(examplesDirectory.path.count + 1))
        : url.lastPathComponent
      let display = url.deletingPathExtension().lastPathComponent
      let tokens = relativePath
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
      files.append(ExampleFile(
        url: url,
        displayName: display,
        relativePath: relativePath,
        searchTokens: tokens
      ))
    }
    return files
  }

  /// Score each file against the query and return them sorted best-first.
  private func rank(files: [ExampleFile], for query: String) -> [ExampleFile] {
    let queryTokens = query
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
    let scored: [(file: ExampleFile, score: Int)] = files.compactMap { file in
      var score = 0
      let displayLower = file.displayName.lowercased()
      let queryLower   = query.lowercased()
      // Exact filename match
      if displayLower == queryLower {
        score += 100
      }
      // Substring match in filename
      if displayLower.contains(queryLower) {
        score += 50
      }
      // Query tokens appearing in filename
      for token in queryTokens where displayLower.contains(token) {
        score += 10
      }
      // Token-level match against full relative path tokens
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
