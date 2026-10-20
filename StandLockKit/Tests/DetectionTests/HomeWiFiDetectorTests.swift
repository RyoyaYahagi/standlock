import Testing
@testable import Detection

@Suite("HomeWiFiDetector Tests")
struct HomeWiFiDetectorTests {
    private let detector = HomeWiFiDetector()

    @Test func allowedSSIDOpensScheduleGate() {
        #expect(detector.decision(currentSSID: "Home Network", allowedSSIDs: ["Home Network"]) == .allowed)
        #expect(detector.allowsSchedule(
            standLockEnabled: true,
            homeWiFiOnly: true,
            currentSSID: "Home Network",
            allowedSSIDs: ["Office", "Home Network"]
        ))
    }

    @Test func unlistedSSIDClosesScheduleGate() {
        #expect(detector.decision(currentSSID: "Guest Network", allowedSSIDs: ["Home Network"]) == .notAllowed)
        #expect(!detector.allowsSchedule(
            standLockEnabled: true,
            homeWiFiOnly: true,
            currentSSID: "Guest Network",
            allowedSSIDs: ["Home Network"]
        ))
    }

    @Test func switchingAwayAndBackStopsAndResumesSchedule() {
        let allowedSSIDs = ["Home Network"]
        let connectionSequence = ["Home Network", "Guest Network", "Home Network"]

        let decisions = connectionSequence.map {
            detector.allowsSchedule(
                standLockEnabled: true,
                homeWiFiOnly: true,
                currentSSID: $0,
                allowedSSIDs: allowedSSIDs
            )
        }

        #expect(decisions == [true, false, true])
    }

    @Test func unavailableSSIDAndEmptyAllowListFailClosed() {
        #expect(detector.decision(currentSSID: nil, allowedSSIDs: ["Home Network"]) == .ssidUnavailable)
        #expect(detector.decision(currentSSID: "Home Network", allowedSSIDs: []) == .noAllowedSSIDs)
        #expect(!detector.allowsSchedule(
            standLockEnabled: true,
            homeWiFiOnly: true,
            currentSSID: nil,
            allowedSSIDs: ["Home Network"]
        ))
    }

    @Test func disabledRestrictionsPreserveExistingBehaviorAndGlobalOffWins() {
        #expect(detector.allowsSchedule(
            standLockEnabled: true,
            homeWiFiOnly: false,
            currentSSID: nil,
            allowedSSIDs: []
        ))
        #expect(!detector.allowsSchedule(
            standLockEnabled: false,
            homeWiFiOnly: false,
            currentSSID: "Home Network",
            allowedSSIDs: ["Home Network"]
        ))
    }
}
