//
//  Logger.swift
//  scrobble
//
//  Created by Brett Henderson on 12/8/25.
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
    
    private static func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
    
    
    // ANSI color for terminal/console output
    private static let reset = "\u{001B}[0m"
    private static let colors: [OSLogType: String] = [
        .debug: "\u{001B}[36m",    // Cyan
        .info: "\u{001B}[32m",     // Green
        .error: "\u{001B}[31m",    // Red
        .fault: "\u{001B}[35m",     // Magenta
        .default: "\u{001B}[37m"   // White
    ]
    
    
    static func debug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let color = colors[.debug]!
        print("\(color)[\(category.rawValue)]: \(message)\(reset)")
        #endif
        logger(for: category).debug("\(message)")
    }
    
    static func info(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let color = colors[.info]!
        print("\(color)[\(category.rawValue)]: \(message)\(reset)")
        #endif
        logger(for: category).info("\(message)")
    }
    
    static func error(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let color = colors[.error]!
        print("\(color)[\(category.rawValue)]: \(message)\(reset)")
        #endif
        logger(for: category).error("\(message)")
    }
    
    static func fault(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let color = colors[.fault]!
        print("\(color)[\(category.rawValue)]: \(message)\(reset)")
        #endif
        logger(for: category).fault("\(message)")
    }
        
        
}
