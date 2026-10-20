import Foundation
import Testing
@testable import Coordination
import StandLockCore

@Suite("Camera and Microphone Deferral Tests")
struct CameraMicrophoneDeferralTests {
    private actor TestDetector: ContextDetecting {
        private var context: DetectionContext
        private var firstContext: DetectionContext?

        init(context: DetectionContext, firstContext: DetectionContext? = nil) {
            self.context = context
            self.firstContext = firstContext
        }

        func setContext(_ context: DetectionContext) { self.context = context }

        func currentContext() async -> DetectionContext {
            if let firstContext {
                self.firstContext = nil
                return firstContext
            }
            return context
        }
    }

    private func activeContext(for device: String) -> DetectionContext {
        DetectionContext(cameraActive: device == "camera", microphoneActive: device == "microphone")
    }

    @Test(arguments: ["camera", "microphone"])
    @MainActor
    func activationAfterEarlyCheckPreventsOverlay(device: String) async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.1)
        // The device starts after the early check but before the break deadline.
        let detector = TestDetector(context: activeContext(for: device), firstContext: .clear)
        let locker = MockLocker()
        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.05
        )
        var deferred = false
        let listener = Task {
            for await event in coordinator.events {
                if case .breakDeferred = event { deferred = true }
            }
        }
        defer { coordinator.stop(); listener.cancel() }

        coordinator.start(with: [makeSchedule()], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        #expect(deferred)
    }

    @Test(arguments: ["camera", "microphone"])
    @MainActor
    func staysDeferredUntilDeviceStops(device: String) async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = TestDetector(context: activeContext(for: device))
        let locker = MockLocker()
        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.05
        )
        var reasons: [DeferralReason] = []
        let listener = Task {
            for await event in coordinator.events {
                if case .breakDeferred(let reason, _) = event { reasons.append(reason) }
            }
        }
        defer { coordinator.stop(); listener.cancel() }

        coordinator.start(with: [makeSchedule(level: .firm)], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!locker.showOverlayCalled)
        #expect(reasons.count >= 2)
        #expect(reasons.allSatisfy { $0 == (device == "camera" ? .cameraActive : .microphoneActive) })

        await detector.setContext(.clear)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(locker.showOverlayCalled)
        #expect(locker.lastLevel == .firm)
    }

    @Test @MainActor
    func bothDevicesMustStopBeforeOverlayAppears() async {
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let detector = TestDetector(context: DetectionContext(cameraActive: true, microphoneActive: true))
        let locker = MockLocker()
        let coordinator = BreakCoordinator(
            scheduler: scheduler, detector: detector, locker: locker,
            deferralPollingInterval: 0.05
        )
        defer { coordinator.stop() }
        coordinator.start(with: [makeSchedule()], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!locker.showOverlayCalled)

        await detector.setContext(DetectionContext(microphoneActive: true))
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!locker.showOverlayCalled)

        await detector.setContext(.clear)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(locker.showOverlayCalled)
    }
}
