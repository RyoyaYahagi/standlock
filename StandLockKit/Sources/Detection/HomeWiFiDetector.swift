import Foundation

/// The result of comparing the currently connected SSID with the user's allow-list.
public enum HomeWiFiDecision: Sendable, Equatable {
    case allowed
    case notAllowed
    case ssidUnavailable
    case noAllowedSSIDs
}

/// Applies the Home Wi-Fi schedule gate without reading or retaining network history.
public struct HomeWiFiDetector: Sendable {
    public init() {}

    public func decision(currentSSID: String?, allowedSSIDs: [String]) -> HomeWiFiDecision {
        guard !allowedSSIDs.isEmpty else { return .noAllowedSSIDs }
        guard let currentSSID, !currentSSID.isEmpty else { return .ssidUnavailable }
        return allowedSSIDs.contains(currentSSID) ? .allowed : .notAllowed
    }

    /// A disabled Wi-Fi restriction preserves the existing schedule behavior.
    public func allowsSchedule(
        standLockEnabled: Bool,
        homeWiFiOnly: Bool,
        currentSSID: String?,
        allowedSSIDs: [String]
    ) -> Bool {
        guard standLockEnabled else { return false }
        guard homeWiFiOnly else { return true }
        return decision(currentSSID: currentSSID, allowedSSIDs: allowedSSIDs) == .allowed
    }
}
