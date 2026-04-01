import ServiceManagement
import SwiftUI

/// ClipStash — a premium macOS clipboard manager.
/// Lives in the menu bar, captures clipboard history, provides instant search.
@main
struct ClipStashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — this is a menu bar-only app.
        // We handle the Settings UI manually via `SettingsWindowManager`.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Settings View (minimal V1)

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 340)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @AppStorage("allowPasswordManagerCapture") private var allowPasswordManagerCapture = true
    @AppStorage(HistoryRetentionPolicy.userDefaultsKey)
    private var historyRetentionPolicy = HistoryRetentionPolicy.defaultValue.rawValue

    private let repository = ClipRepository()

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Privacy") {
                Toggle("Capture from Password Managers", isOn: $allowPasswordManagerCapture)
                Text("If enabled, ClipStash captures from 1Password, LastPass, Bitwarden, etc.\nIf disabled, they are silently ignored.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("History") {
                Picker("Keep Clipboard History", selection: $historyRetentionPolicy) {
                    ForEach(HistoryRetentionPolicy.allCases) { policy in
                        Text(policy.title)
                            .tag(policy.rawValue)
                    }
                }
                Text(selectedRetentionPolicy.description + " Pinned clips are never removed automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard Shortcut") {
                HStack {
                    Text("Toggle ClipStash")
                    Spacer()
                    Text("⌥V")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                        }
                }
            }

            Section("AI Features") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Semantic Search")
                        Spacer()
                        Label("Enabled", systemImage: "circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 11))
                    }
                    Text("Powered by Apple NLEmbedding. Works locally, no account needed.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onChange(of: historyRetentionPolicy) { _, newValue in
            guard let policy = HistoryRetentionPolicy(rawValue: newValue) else { return }
            applyRetentionPolicy(policy)
        }
    }

    private var selectedRetentionPolicy: HistoryRetentionPolicy {
        HistoryRetentionPolicy(rawValue: historyRetentionPolicy) ?? .defaultValue
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    private func applyRetentionPolicy(_ policy: HistoryRetentionPolicy) {
        guard let cutoffDate = policy.cutoffDate else { return }

        do {
            try repository.deleteOlderThan(cutoffDate)
        } catch {
            print("Retention cleanup error: \(error)")
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 56, height: 56)

            VStack(spacing: 4) {
                Text("ClipStash")
                    .font(.system(size: 20, weight: .bold))

                Text("Version 2.3.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("A premium clipboard manager for macOS.\nPowered by SQLite & NLEmbedding.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
