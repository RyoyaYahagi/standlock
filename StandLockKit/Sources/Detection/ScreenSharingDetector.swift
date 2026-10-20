import AppKit

public struct ScreenSharingDetector: Sendable {
    private let processNames: @Sendable () -> [String]

    public init() {
        self.processNames = {
            NSWorkspace.shared.runningApplications.compactMap { $0.executableURL?.lastPathComponent }
        }
    }

    init(processNames: @escaping @Sendable () -> [String]) {
        self.processNames = processNames
    }

    public func isScreenBeingShared() async -> Bool {
        // The screenshot utility can remain running after a screenshot or recording
        // ends. Its presence alone is not evidence of an active capture session.
        processNames().contains { $0 == "ScreensharingAgent" }
    }
}
