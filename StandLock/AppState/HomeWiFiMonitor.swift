import AppKit
@preconcurrency import CoreLocation
@preconcurrency import CoreWLAN
import SwiftUI

@MainActor
final class HomeWiFiMonitor: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    enum Status: Equatable {
        case stopped
        case authorizationRequired
        case authorizationDenied
        case authorizationRestricted
        case connected(String)
        case ssidUnavailable
    }

    @Published private(set) var status: Status = .stopped

    private let wifiClient = CWWiFiClient.shared()
    private var pollingTask: Task<Void, Never>?

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    var currentSSID: String? {
        guard case .connected(let ssid) = status else { return nil }
        return ssid
    }

    func requestLocationAccess() {
        let manager = locationManager
        if manager.authorizationStatus == .notDetermined {
            NSApp.activate(ignoringOtherApps: true)
            manager.requestWhenInUseAuthorization()
        } else {
            refreshSSID()
        }
    }

    func startMonitoring() {
        guard pollingTask == nil else {
            refreshSSID()
            return
        }

        refreshSSID()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                self.refreshSSID()
            }
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
        status = .stopped
    }

    func openLocationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
        ].compactMap(URL.init(string:))

        for url in candidates {
            if NSWorkspace.shared.open(url) { return }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pollingTask != nil else { return }
        refreshSSID()
    }

    private func refreshSSID() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            status = .authorizationRequired
        case .denied:
            status = .authorizationDenied
        case .restricted:
            status = .authorizationRestricted
        case .authorizedAlways, .authorizedWhenInUse:
            if let ssid = wifiClient.interface()?.ssid(), !ssid.isEmpty {
                status = .connected(ssid)
            } else {
                status = .ssidUnavailable
            }
        @unknown default:
            status = .ssidUnavailable
        }
    }
}
