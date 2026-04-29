// swift-tools-version: 5.9
//
//  Package.swift
//  LispKitAssist
//  
//  Created by Matthias Zenger on 29/04/2026.
//  Copyright © 2026 ObjectHub. All rights reserved.
//  
//  Licensed under the Apache License, Version 2.0 (the "License"); you
//  may not use this file except in compliance with the License.
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

import PackageDescription

let package = Package(
  name: "LispKitAssist",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "LispKitAssist",
      targets: ["LispKitAssist"]
    ),
    .executable(
      name: "LispKitCLI",
      targets: ["LispKitCLI"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/objecthub/swift-commandlinekit.git", from: "1.0.0"),
    .package(url: "https://github.com/objecthub/swift-dynamicjson.git", branch: "main")
  ],
  targets: [
    .target(
      name: "LispKitAssist",
      dependencies: [
        .product(name: "DynamicJSON", package: "swift-dynamicjson"),
      ],
      linkerSettings: [
        // Required for Keychain access on macOS
        .linkedFramework("Security")
      ]
    ),
    .executableTarget(
      name: "LispKitCLI",
      dependencies: [
        .target(name: "LispKitAssist"),
        .product(name: "CommandLineKit", package: "swift-commandlinekit")
      ]
    ),
    .testTarget(
      name: "LispKitAssistTests",
      dependencies: ["LispKitAssist"]
    )
  ]
)
