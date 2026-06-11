import AppKit

public struct AppAnchor: Identifiable, Equatable {
    public let id: String
    public let appName: String
    public let bundleIdentifier: String?
    public let processIdentifier: pid_t
    public let icon: NSImage?
    public let lastActiveAt: Date?
    public let canActivate: Bool

    public init(
        id: String,
        appName: String,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        icon: NSImage?,
        lastActiveAt: Date?,
        canActivate: Bool
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.icon = icon
        self.lastActiveAt = lastActiveAt
        self.canActivate = canActivate
    }

    public static func == (lhs: AppAnchor, rhs: AppAnchor) -> Bool {
        lhs.id == rhs.id &&
            lhs.appName == rhs.appName &&
            lhs.bundleIdentifier == rhs.bundleIdentifier &&
            lhs.processIdentifier == rhs.processIdentifier &&
            lhs.lastActiveAt == rhs.lastActiveAt &&
            lhs.canActivate == rhs.canActivate
    }
}
