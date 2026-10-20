import SwiftUI
import StandLockCore

struct DetectionSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissionChecker: PermissionChecker
    @State private var showCalendarPermissionAlert = false
    @State private var newWiFiSSID = ""

    var body: some View {
        Form {
            Section("Home Wi-Fi only") {
                Toggle(isOn: Binding(
                    get: { coordinator.preferences.homeWiFiOnly },
                    set: { coordinator.setHomeWiFiOnly($0) }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Home Wi-Fi only")
                            Text("Run break schedules only on selected Wi-Fi networks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "wifi")
                    }
                }

                if coordinator.preferences.homeWiFiOnly {
                    Text("macOS requires Location Services permission to read the current Wi-Fi name (SSID). StandLock reads only the current SSID; it never reads or stores coordinates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    homeWiFiStatus
                    allowedWiFiNetworks
                }
            }

            Section("Video & Audio") {
                detectionRow(
                    title: "Camera Detection",
                    description: "Defer breaks when camera is active (video calls)",
                    systemImage: "camera",
                    behavior: $coordinator.preferences.cameraDetection
                )

                detectionRow(
                    title: "Microphone Detection",
                    description: "Defer breaks when microphone is active (audio calls)",
                    systemImage: "mic",
                    behavior: $coordinator.preferences.microphoneDetection
                )
            }

            Section("Calendar") {
                Toggle(isOn: permissionChecker.gatedToggle(
                    for: $coordinator.preferences.calendarDetectionEnabled,
                    available: permissionChecker.calendarIntegrationAvailable,
                    onDenied: { showCalendarPermissionAlert = true }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Integration")
                            Text("Defer breaks during calendar events")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }

                if permissionChecker.calendarIntegrationAvailable
                    && coordinator.preferences.calendarDetectionEnabled {
                    Stepper(
                        "Look-ahead: \(coordinator.preferences.calendarLookAheadMinutes) min",
                        value: $coordinator.preferences.calendarLookAheadMinutes,
                        in: 1...15
                    )
                    .padding(.leading, 24)

                    Picker("Calendars", selection: $coordinator.preferences.calendarSelectionMode) {
                        Text("All calendars").tag(CalendarSelectionMode.all)
                        Text("Specific calendars").tag(CalendarSelectionMode.selected)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.leading, 24)

                    if coordinator.preferences.calendarSelectionMode == .selected {
                        calendarSelection
                    }
                }

                Toggle(isOn: $coordinator.preferences.screenSharingDetectionEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Sharing")
                            Text("Defer breaks during remote screen sharing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.inset.filled.and.person.filled")
                    }
                }

                if coordinator.preferences.screenSharingDetectionEnabled {
                    Picker("After sharing ends", selection: $coordinator.preferences.screenSharingPostDeferral) {
                        Text("Start break").tag(PostDeferralBehavior.triggerBreak)
                        Text("Skip break").tag(PostDeferralBehavior.skipBreak)
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 24)
                }
            }

            Section("Media & Idle") {
                Toggle(isOn: $coordinator.preferences.pauseMediaDuringBreak) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause Media")
                            Text("Pause audio playback when a break starts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "speaker.slash")
                    }
                }

                Toggle(isOn: $coordinator.preferences.idleDetectionEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Idle as Break")
                            Text("Count inactivity as a break taken")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "zzz")
                    }
                }
            }

        }
        .formStyle(.grouped)
        .onChange(of: coordinator.preferences) { _ in
            coordinator.savePreferences()
        }
        .onChange(of: coordinator.preferences.calendarSelectionMode) { mode in
            // Pre-check every calendar when the choice flips to a specific selection, so it
            // starts as a no-op the user then narrows down. Leaving this in the list's task
            // would re-tick everything each time the Settings tab is reopened.
            guard mode == .selected,
                  coordinator.preferences.selectedCalendarIdentifiers.isEmpty else { return }
            coordinator.refreshAvailableCalendars()
            coordinator.preferences.selectedCalendarIdentifiers =
                coordinator.availableCalendars.map(\.id)
        }
        .alert("Calendar Permission Required", isPresented: $showCalendarPermissionAlert) {
            Button("Open System Settings") {
                permissionChecker.openSystemSettings(for: .calendar)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Calendar Integration requires calendar access. Grant it in System Settings to enable this feature.")
        }
    }

    @ViewBuilder
    private var homeWiFiStatus: some View {
        switch coordinator.homeWiFiStatus {
        case .stopped:
            Label("Wi-Fi checking is stopped while StandLock is off", systemImage: "pause.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .authorizationRequired:
            VStack(alignment: .leading, spacing: 6) {
                Label("Location access is needed to read the current SSID", systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Open Location Settings") {
                    coordinator.openHomeWiFiLocationSettings()
                }
                .controlSize(.small)
            }
        case .authorizationDenied:
            VStack(alignment: .leading, spacing: 6) {
                Label("Location access was denied. Enable it in System Settings > Privacy & Security > Location Services.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Open Location Settings") {
                    coordinator.openHomeWiFiLocationSettings()
                }
                .controlSize(.small)
            }
        case .authorizationRestricted:
            Label("Location access is restricted by macOS or device management", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .connected(let ssid):
            HStack(spacing: 8) {
                Label("Current Wi-Fi", systemImage: "wifi")
                    .font(.caption)
                Spacer()
                Text(verbatim: ssid)
                    .font(.caption)
                    .textSelection(.enabled)
                if !coordinator.preferences.allowedWiFiSSIDs.contains(ssid) {
                    Button("Add Current Network") {
                        coordinator.addAllowedWiFiSSID(ssid)
                    }
                    .controlSize(.small)
                }
            }
        case .ssidUnavailable:
            Label("macOS could not provide the current SSID. Check the Wi-Fi connection and Location Services access.", systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var allowedWiFiNetworks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allowed Wi-Fi Networks")
                .font(.subheadline)
                .fontWeight(.medium)

            if coordinator.preferences.allowedWiFiSSIDs.isEmpty {
                Text("Add at least one SSID. Schedules stay stopped until an allowed network is connected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(coordinator.preferences.allowedWiFiSSIDs.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("Wi-Fi name (SSID)", text: Binding(
                        get: { coordinator.preferences.allowedWiFiSSIDs[index] },
                        set: { coordinator.updateAllowedWiFiSSID(at: index, to: $0) }
                    ))
                    Button {
                        coordinator.removeAllowedWiFiSSID(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove Wi-Fi network")
                }
            }

            HStack(spacing: 8) {
                TextField("Wi-Fi name (SSID)", text: $newWiFiSSID)
                    .onSubmit(addTypedSSID)
                Button("Add", action: addTypedSSID)
                    .disabled(newWiFiSSID.isEmpty)
            }
        }
        .padding(.leading, 24)
    }

    private func addTypedSSID() {
        coordinator.addAllowedWiFiSSID(newWiFiSSID)
        newWiFiSSID = ""
    }

    private func detectionRow(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        systemImage: String,
        behavior: Binding<DetectionBehavior>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }

            Picker("Behavior", selection: behavior) {
                Text("Defer break").tag(DetectionBehavior.deferBreak)
                Text("Reduce to Gentle").tag(DetectionBehavior.reduceToGentle)
                Text("Ignore").tag(DetectionBehavior.ignore)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.leading, 24)
        }
    }

    @ViewBuilder
    private var calendarSelection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Only checked calendars defer breaks")
                .font(.caption)
                .foregroundStyle(.secondary)

            if coordinator.availableCalendars.isEmpty {
                Text("No calendars found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coordinator.availableCalendars) { calendar in
                    Toggle(isOn: calendarBinding(for: calendar)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: calendar.title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !calendar.source.isEmpty {
                                Text(verbatim: calendar.source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        .padding(.leading, 24)
        .task { coordinator.refreshAvailableCalendars() }
    }

    private func calendarBinding(for calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { coordinator.preferences.selectedCalendarIdentifiers.contains(calendar.id) },
            set: { selected in
                var identifiers = coordinator.preferences.selectedCalendarIdentifiers
                if selected {
                    if !identifiers.contains(calendar.id) { identifiers.append(calendar.id) }
                } else {
                    identifiers.removeAll { $0 == calendar.id }
                }
                coordinator.preferences.selectedCalendarIdentifiers = identifiers
            }
        )
    }
}
