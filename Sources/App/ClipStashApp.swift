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
        .frame(width: 420, height: 280)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var openAIApiKey = KeychainHelper.load(account: "openai") ?? ""

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
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
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OpenAI API Key (For Summaries & Tags)")
                        Spacer()
                    }
                    
                    SecureField("sk-proj-...", text: $openAIApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: openAIApiKey) { _, newValue in
                            if newValue.starts(with: "sk-") {
                                try? KeychainHelper.save(newValue, account: "openai")
                            } else if newValue.isEmpty {
                                KeychainHelper.delete(account: "openai")
                            }
                        }
                    
                    Text("API keys are stored securely in macOS Keychain. Required for auto-summaries and tags.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
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
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#58A6FF"),
                            Color(hex: "#A371F7"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                Text("ClipStash")
                    .font(.system(size: 20, weight: .bold))

                Text("Version 1.0")
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
