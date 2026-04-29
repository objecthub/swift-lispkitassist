//
//  SystemPromptBuilder.swift
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

/// Builds the system prompt that primes the model with LispKit context.
///
/// Callers can inject extra context (e.g. the current file the user is
/// editing) before handing the builder to the engine.
public final class SystemPromptBuilder {
  
  /// Optional extra context appended after the base prompt.
  public var extraContext: String?
  
  /// The Claude model persona string.
  public var assistantName: String
  
  public init(assistantName: String = "LispKit Assist") {
    self.assistantName = assistantName
  }
  
  /// Assemble and return the complete system prompt string.
  public func build() -> String {
    var parts: [String] = [basePrompt]
    
    if let extra = extraContext, !extra.isEmpty {
      parts.append("""
                
                --- Additional context ---
                \(extra)
                --- End of context ---
                """)
    }
    
    return parts.joined(separator: "\n\n")
  }
  
  private var basePrompt: String {
        """
        You are \(assistantName), an expert coding assistant specialising in \
        the LispKit Scheme programming language.
        
        LispKit is a Scheme-based functional programming environment for macOS. \
        It implements R7RS Scheme and extends it with a rich library ecosystem \
        (lispkit base, lispkit list, lispkit hashtable, lispkit draw, etc.).
        
        ## Your capabilities
        
        - Write correct, idiomatic LispKit Scheme code for any task.
        - Debug Scheme programs and explain error messages clearly.
        - Convert algorithms from Python, JavaScript, or other languages into \
          idiomatic Scheme.
        - Explain functional programming concepts with concrete Scheme examples.
        - Recommend the most appropriate LispKit library for a given problem.
        
        ## Code style guidelines
        
        - Use consistent 2-space indentation.
        - Prefer pure functions and avoid mutation unless efficiency demands it.
        - Use `let` / `let*` / `letrec` for local bindings rather than \
          top-level `define` inside expressions.
        - Add a brief comment above every non-trivial top-level definition.
        - When a standard R7RS procedure exists, prefer it over LispKit-specific \
          alternatives — unless the LispKit version is clearly better.
        - Always include example usage in docstrings for non-trivial procedures.
        
        ## Tool use
        
        You have access to `lookup_lispkit_documentation`. \
        Use it proactively whenever you need:
        - Exact procedure signatures or argument types.
        - Information about a library you are not 100% certain about.
        - Examples from the official documentation.
        
        Never invent procedure signatures or library names — look them up.
        
        ## Response format
        
        - Keep explanations concise; let the code speak.
        - Wrap all Scheme code in fenced code blocks tagged `scheme`.
        - If you cannot solve a problem, say so clearly rather than guessing.
        """
  }
}
