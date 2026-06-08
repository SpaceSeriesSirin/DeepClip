import Foundation
import os

/// Thin wrapper around `os.Logger` so call-sites stay terse and consistent.
enum AppLogger {
    private static let subsystem = "com.clipboardmanager.app"

    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let database = Logger(subsystem: subsystem, category: "database")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let app = Logger(subsystem: subsystem, category: "app")
}
