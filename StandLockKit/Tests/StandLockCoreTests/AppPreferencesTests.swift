import Foundation
import Testing
@testable import StandLockCore

@Suite("AppPreferences Tests")
struct AppPreferencesTests {
    @Test func olderPreferencesDefaultToEnabledWithoutWiFiRestriction() throws {
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))

        #expect(preferences.standLockEnabled)
        #expect(!preferences.homeWiFiOnly)
        #expect(preferences.allowedWiFiSSIDs.isEmpty)
    }

    @Test func newSettingsSurviveUserDefaultsStyleCodableRoundTrip() throws {
        let preferences = AppPreferences(
            standLockEnabled: false,
            homeWiFiOnly: true,
            allowedWiFiSSIDs: ["Home Network", "Office Network"]
        )

        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))

        #expect(restored.standLockEnabled == false)
        #expect(restored.homeWiFiOnly)
        #expect(restored.allowedWiFiSSIDs == ["Home Network", "Office Network"])
    }
}
