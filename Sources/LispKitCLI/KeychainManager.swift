//
//  KeychainManager.swift
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
import Security

public enum KeychainError: Error, LocalizedError {
  case saveFailure(OSStatus)
  case readFailure(OSStatus)
  case deleteFailure(OSStatus)
  case unexpectedDataFormat
  
  public var errorDescription: String? {
    switch self {
      case .saveFailure(let status):
        return "Keychain save failed (OSStatus \(status)): " +
               (SecCopyErrorMessageString(status, nil) as String? ?? "unknown")
      case .readFailure(let status):
        return "Keychain read failed (OSStatus \(status)): " +
               (SecCopyErrorMessageString(status, nil) as String? ?? "unknown")
      case .deleteFailure(let status):
        return "Keychain delete failed (OSStatus \(status)): " +
               (SecCopyErrorMessageString(status, nil) as String? ?? "unknown")
      case .unexpectedDataFormat:
        return "The value stored in the Keychain is not a UTF-8 string."
    }
  }
}

/// Thread-safe wrapper around the macOS Security framework Keychain APIs.
/// Used to store and retrieve the Anthropic API key.
public struct KeychainManager: Sendable {
  
  /// The service name used as the Keychain namespace.
  private let service: String
  
  public init(service: String = "com.lispkitassist") {
    self.service = service
  }
  
  /// Persist `value` under `account` in the Keychain,
  /// creating or updating the item as needed.
  public func save(_ value: String, account: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.unexpectedDataFormat
    }
    // If the item already exists, update it instead of inserting.
    if (try? read(account: account)) != nil {
      let query  = baseQuery(account: account)
      let update = [kSecValueData as String: data] as CFDictionary
      let status = SecItemUpdate(query as CFDictionary, update)
      guard status == errSecSuccess else {
        throw KeychainError.saveFailure(status)
      }
    } else {
      var query = baseQuery(account: account)
      query[kSecValueData as String] = data
      let status = SecItemAdd(query as CFDictionary, nil)
      guard status == errSecSuccess else {
        throw KeychainError.saveFailure(status)
      }
    }
  }
  
    /// Retrieve a previously saved value, or `nil` if not found.
  public func read(account: String) throws -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String]  = true
    query[kSecMatchLimit as String]  = kSecMatchLimitOne
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else {
      throw KeychainError.readFailure(status)
    }
    guard let data = result as? Data,
          let string = String(data: data, encoding: .utf8)
    else {
      throw KeychainError.unexpectedDataFormat
    }
    return string
  }
  
  /// Remove a stored value.  A no-op if the item does not exist.
  public func delete(account: String) throws {
    let query  = baseQuery(account: account)
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.deleteFailure(status)
    }
  }
  
  private func baseQuery(account: String) -> [String: Any] {
    return [
      kSecClass as String:   kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

public extension KeychainManager {
  private static let apiKeyAccount = "anthropic-api-key"
  
  /// Store the Anthropic API key.
  func saveAPIKey(_ key: String) throws {
    try save(key, account: Self.apiKeyAccount)
  }
  
  /// Retrieve the Anthropic API key, or `nil` if not yet configured.
  func loadAPIKey() throws -> String? {
    try read(account: Self.apiKeyAccount)
  }
  
  /// Remove the stored API key.
  func deleteAPIKey() throws {
    try delete(account: Self.apiKeyAccount)
  }
}
