import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var appState: AppState

    @State private var selectedIgnoredApp: String?

    /// Resolves a bundle identifier to a human-readable app name via NSWorkspace.
    private func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Max items")
                    Spacer()
                    TextField("", value: $settings.maxItems, format: .number)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.maxItems, in: 10...100_000, step: 50)
                        .labelsHidden()
                }
                Text("Oldest non-pinned items are removed once this limit is exceeded.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("Cache duration (days)")
                    Spacer()
                    TextField("", value: $settings.cacheDays, format: .number)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.cacheDays, in: 0...3650, step: 1)
                        .labelsHidden()
                }
                Text("Items older than this expire automatically. Pinned items never expire. 0 = keep forever.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Monitoring") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Poll interval")
                        Spacer()
                        Text(String(format: "%.1f s", settings.pollInterval))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.pollInterval, in: 0.1...3.0, step: 0.1)
                }
                Text("How often the clipboard is checked for changes.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("Monitoring")
                    Spacer()
                    if appState.isMonitoringPaused {
                        Label("Paused", systemImage: "pause.circle.fill")
                            .foregroundStyle(.orange)
                        Button("Resume") { appState.resumeMonitoring() }
                            .controlSize(.small)
                    } else {
                        Label("Active", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                        Button("Pause") { appState.pauseMonitoring() }
                            .controlSize(.small)
                    }
                }

                Picker("Auto-resume after", selection: $settings.autoResumeMinutes) {
                    Text("Never").tag(0)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("60 minutes").tag(60)
                }
                Text("When monitoring is paused, automatically resume after this delay. \"Never\" keeps it paused until resumed manually.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Ignored Apps") {
                let ids = settings.ignoredBundleIDs
                if ids.isEmpty {
                    Text("No apps ignored. Copies from every app are captured.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    List(selection: $selectedIgnoredApp) {
                        ForEach(ids, id: \.self) { bundleID in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(appName(for: bundleID))
                                Text(bundleID)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(bundleID)
                        }
                    }
                    .frame(minHeight: 80, maxHeight: 160)
                }

                HStack {
                    Button {
                        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                            settings.addIgnoredApp(bundleID)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add the current frontmost app")

                    Button {
                        if let selected = selectedIgnoredApp {
                            settings.removeIgnoredApp(selected)
                            selectedIgnoredApp = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedIgnoredApp == nil)
                    .help("Remove the selected app")

                    Spacer()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("Clipboard content copied while one of these apps is frontmost is never captured. Use \"+\" to add the app you're currently using (switch to it first, then open Settings).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle("Ignore password manager content", isOn: $settings.ignorePrivacyTypes)
                Text("Skip clipboard items marked as concealed, transient, or auto-generated by password managers (1Password, Bitwarden, …) and the system. These are never stored.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Global Hotkey") {
                Toggle("Enable global hotkey", isOn: $settings.enableHotkey)

                HStack {
                    Text("Shortcut")
                    Spacer()
                    HotkeyRecorderView(
                        keyCode: $settings.hotkeyKeyCode,
                        modifiers: $settings.hotkeyModifiers
                    )
                    .disabled(!settings.enableHotkey)
                }

                Picker("Summon", selection: $settings.hotkeyTarget) {
                    Text("Main Window").tag("main")
                    Text("Menu Bar Popover").tag("popover")
                    Text("Quick Panel").tag("quickpanel")
                }
                .disabled(!settings.enableHotkey)

                Text("Press this shortcut from any app to bring DeepClip to the front. Requires at least one modifier (⌘, ⌥, ⌃, ⇧).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Auto-Paste") {
                Toggle("Paste directly into the previous app", isOn: $settings.enableAutoPaste)
                HStack {
                    Text("Accessibility permission")
                    Spacer()
                    if AutoPasteService.hasPermission {
                        Text("Granted").foregroundStyle(.green)
                    } else {
                        Button("Grant…") { AutoPasteService.requestPermission() }
                            .controlSize(.small)
                    }
                }
                .font(.caption)
                Text("When you choose an item, it is pasted into the app you were last using (⌘V). Requires Accessibility permission. If unavailable, the item is just copied to the clipboard.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                HStack {
                    Text("Login item status")
                    Spacer()
                    Text(AutoStartService.statusDescription)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }
}
