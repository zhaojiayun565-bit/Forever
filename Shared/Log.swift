import os

/// Unified logging categories. Interpolated values default to private in release logs.
nonisolated enum Log {
    private static let subsystem = "com.jiayunzhao.Forever"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let realtime = Logger(subsystem: subsystem, category: "realtime")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let drawing = Logger(subsystem: subsystem, category: "drawing")
    static let push = Logger(subsystem: subsystem, category: "push")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    static let purchases = Logger(subsystem: subsystem, category: "purchases")
}
