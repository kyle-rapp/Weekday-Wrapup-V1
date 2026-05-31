import Foundation

struct AppLogger {
    static func log(_ message: String) {
        #if DEBUG
        print("LOG: \(message)")
        #endif
    }

    static func error(_ message: String) {
        print("ERROR: \(message)")
    }
}
