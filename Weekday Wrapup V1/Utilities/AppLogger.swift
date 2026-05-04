import Foundation

struct AppLogger {
    static func log(_ message: String) {
        print("LOG: \(message)")
    }

    static func error(_ message: String) {
        print("ERROR: \(message)")
    }
}
