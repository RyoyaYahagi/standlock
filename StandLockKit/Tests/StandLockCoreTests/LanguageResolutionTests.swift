import Foundation
import Testing
@testable import StandLockCore

@Suite("Language Resolution")
struct LanguageResolutionTests {

    @Test func explicitSelectionWins() {
        #expect(resolveLanguage(selection: "tr", available: ["en", "tr"], systemPreferred: ["en"]) == "tr")
    }

    @Test func unavailableSelectionFallsBackToSystem() {
        #expect(resolveLanguage(selection: "de", available: ["en", "tr"], systemPreferred: ["tr"]) == "tr")
    }

    @Test func systemRegionTagMatchesByLanguageCode() {
        #expect(resolveLanguage(selection: nil, available: ["en", "tr"], systemPreferred: ["tr-TR", "en"]) == "tr")
    }

    @Test func noSystemMatchFallsBackToEnglish() {
        #expect(resolveLanguage(selection: nil, available: ["en", "tr"], systemPreferred: ["ja", "fr"]) == "en")
    }

    @Test func emptyAvailableFallsBackToEnglish() {
        #expect(resolveLanguage(selection: nil, available: [], systemPreferred: ["tr"]) == "en")
    }

    @Test func selectionWithRegionTagMatchesByLanguageCode() {
        #expect(resolveLanguage(selection: "tr-TR", available: ["en", "tr"], systemPreferred: ["en"]) == "tr")
    }

    @Test func explicitJapaneseSelectionWins() {
        #expect(resolveLanguage(selection: "ja", available: ["en", "ja", "tr"], systemPreferred: ["en"]) == "ja")
    }

    @Test func japaneseSystemLanguageUsesJapaneseCatalog() {
        #expect(resolveLanguage(selection: nil, available: ["en", "ja", "tr"], systemPreferred: ["ja-JP", "en"]) == "ja")
    }

    @Test func systemEnglishRemainsEnglishWhenJapaneseIsAvailable() {
        #expect(resolveLanguage(selection: nil, available: ["en", "ja", "tr"], systemPreferred: ["en-US", "ja-JP"]) == "en")
    }
}
