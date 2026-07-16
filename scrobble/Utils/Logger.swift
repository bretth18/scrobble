//
//  Logger.swift
//  scrobble
//
//  Created by Brett Henderson on 12/8/25.
//
//  Thin wrapper over os.Logger. Output goes to the unified logging system
//  only — os.Logger already surfaces in the Xcode console and Console.app,
//  so there is no separate print() path (a second sink just duplicates
//  every line, and ANSI color codes render as garbage in both consoles).
//
//  Never log credentials: session keys, API keys/secrets, auth tokens,
//  or signed request parameter dictionaries.
//

import Foundation
import os

enum LogCategory: String, CaseIterable {
    case auth = "Authentication"
    case scrobble = "Scrobbling"
    case network = "Network"
    case ui = "User Interface"
    case general = "General"
}

struct Log {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.app.scrobble"

    private static let loggers: [LogCategory: Logger] = Dictionary(
        uniqueKeysWithValues: LogCategory.allCases.map {
            ($0, Logger(subsystem: subsystem, category: $0.rawValue))
        }
    )

    static func debug(_ message: String, category: LogCategory = .general) {
        loggers[category]!.debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: LogCategory = .general) {
        loggers[category]!.info("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: LogCategory = .general) {
        loggers[category]!.error("\(message, privacy: .public)")
    }

    static func fault(_ message: String, category: LogCategory = .general) {
        loggers[category]!.fault("\(message, privacy: .public)")
    }
}
