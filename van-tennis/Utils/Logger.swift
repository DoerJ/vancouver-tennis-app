import Foundation

enum Logger {
    static func info(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: "INFO",
            message: message(),
            file: file,
            function: function,
            line: line
        )
    }

    static func warn(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: "WARN",
            message: message(),
            file: file,
            function: function,
            line: line
        )
    }

    static func error(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: "ERROR",
            message: message(),
            file: file,
            function: function,
            line: line
        )
    }

    private static func log(
        level: String,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        print("[\(level)] \(file):\(line) \(function) - \(message)")
    }
}
