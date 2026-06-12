import AppKit
import CoreGraphics

@MainActor
public final class AnchorService {
    private var lastActiveByPID: [pid_t: Date] = [:]

    public init() {
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            lastActiveByPID[frontmost.processIdentifier] = Date()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                self?.lastActiveByPID[app.processIdentifier] = Date()
            }
        }
    }

    public func currentAnchors() -> [AppAnchor] {
        let windowOwnerPIDs = visibleWindowOwnerPIDs()
        let ownPID = ProcessInfo.processInfo.processIdentifier

        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                    !app.isTerminated &&
                    app.processIdentifier != ownPID &&
                    windowOwnerPIDs.contains(app.processIdentifier)
            }

        return apps
            .map { app in
                AppAnchor(
                    id: "\(app.processIdentifier)",
                    appName: app.localizedName ?? app.bundleIdentifier ?? "Application",
                    bundleIdentifier: app.bundleIdentifier,
                    processIdentifier: app.processIdentifier,
                    icon: app.icon,
                    lastActiveAt: lastActiveByPID[app.processIdentifier],
                    canActivate: true
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.lastActiveAt, rhs.lastActiveAt) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
                }
            }
    }

    public func activate(_ anchor: AppAnchor) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: anchor.processIdentifier) else {
            return false
        }
        return app.activate(options: [.activateAllWindows])
    }

    private func visibleWindowOwnerPIDs() -> Set<pid_t> {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        }

        var pids = Set<pid_t>()
        for info in infoList {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }

            guard let ownerPIDNumber = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat,
                  width > 24,
                  height > 24 else {
                continue
            }

            pids.insert(ownerPIDNumber.int32Value)
        }

        if pids.isEmpty {
            return Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        }
        return pids
    }
}
