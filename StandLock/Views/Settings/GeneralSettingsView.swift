import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var launchAtStartup = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?
    @State private var isUpdating = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $launchAtStartup) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Startup")
                            Text("Open StandLock when you log in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "laptopcomputer")
                    }
                }
                .onChange(of: launchAtStartup) { newValue in
                    guard !isUpdating else { return }
                    setLaunchAtStartup(newValue)
                }

                if let errorMessage {
                    Text("Failed to update login item: \(errorMessage)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Language") {
                Picker(selection: Binding(
                    get: { languageStore.selection },
                    set: { languageStore.select($0) }
                )) {
                    Text("System").tag(String?.none)
                    ForEach(languageStore.available, id: \.self) { code in
                        Text(languageStore.displayName(for: code)).tag(Optional(code))
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Language")
                            Text("System follows your Mac's language")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "globe")
                    }
                }
            }

            Section("Appearance") {
                Picker(selection: Binding(
                    get: { themeStore.selection },
                    set: { themeStore.select($0) }
                )) {
                    Text("System").tag(String?.none)
                    // Built from the store's list, so a theme added later needs no
                    // change here.
                    ForEach(themeStore.available) { theme in
                        Text(LocalizedStringKey(theme.nameKey)).tag(Optional(theme.id))
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Appearance")
                            Text("System follows your Mac's appearance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                    }
                }
            }

            Section("Menu Bar Display") {
                Toggle(isOn: $coordinator.preferences.showFullWorkTimer) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Full Work Timer")
                            Text("Always display remaining time next to the icon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "timer")
                    }
                }
                .onChange(of: coordinator.preferences.showFullWorkTimer) { _ in
                    coordinator.savePreferences()
                }

                if !coordinator.preferences.showFullWorkTimer {
                    Picker(selection: $coordinator.preferences.menuBarCountdownMinutes) {
                        Text("1 min").tag(1)
                        Text("2 min").tag(2)
                        Text("3 min").tag(3)
                        Text("5 min").tag(5)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Countdown Start")
                                Text("Show timer in the last minutes before break")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.badge.checkmark")
                        }
                    }
                    .onChange(of: coordinator.preferences.menuBarCountdownMinutes) { _ in
                        coordinator.savePreferences()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtStartup(_ enabled: Bool) {
        isUpdating = true
        defer { isUpdating = false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            launchAtStartup = !enabled
            errorMessage = error.localizedDescription
        }
    }
}
