<p align="center">
  <img src="https://img.icons8.com/sf-regular-filled/96/58A6FF/clipboard.png" width="80" alt="ClipStash Icon"/>
</p>

<h1 align="center">ClipStash</h1>

<p align="center">
  <strong>A premium macOS clipboard manager with AI-powered search.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-blue?style=flat-square&logo=apple" alt="macOS 14+"/>
  <img src="https://img.shields.io/badge/Swift-6.1%2B-orange?style=flat-square&logo=swift" alt="Swift 6.1+"/>
  <img src="https://img.shields.io/badge/UI-SwiftUI-purple?style=flat-square" alt="SwiftUI"/>
  <img src="https://img.shields.io/badge/DB-SQLite%20%2B%20FTS5-green?style=flat-square" alt="SQLite"/>
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="MIT License"/>
</p>

---

ClipStash lives in your menu bar and silently captures everything you copy — text, URLs, code snippets, emails — and lets you search, browse, and re-copy from your full clipboard history instantly.

Built for developers and power users who copy dozens of things a day and lose half of them to the next `⌘C`.

## ✨ Features

- **Invisible clipboard history** — Polls `NSPasteboard` every 500ms, stores everything in local SQLite
- **Instant full-text search** — FTS5-powered search across your entire clipboard history
- **Smart content detection** — Auto-classifies clips as text, URL, code, email, or hex color
- **Global hotkey** — `⌥V` to toggle the popover from anywhere
- **Source app tracking** — See which app each clip came from, with the app's icon
- **One-click re-copy** — Click any clip to copy it back to your clipboard
- **Pin important clips** — Pin clips to keep them at the top permanently
- **Privacy Controls** — Configurable capturing from password managers (1Password, LastPass, Bitwarden, Dashlane, KeePassXC, Keychain Access)
- **Retention Controls** — Automatically remove old non-pinned clips after 7 days, 30 days, or never
- **AI-powered** — Native on-device semantic search using Apple's `NLEmbedding` framework
- **No Dock icon** — Pure menu bar app. Zero visual noise.

## 🏗 Architecture

```
┌─────────────────────────────────────────┐
│           SwiftUI Menu Bar App           │
│                                         │
│  ┌─────────────┐    ┌────────────────┐  │
│  │ NSPasteboard│    │   SwiftUI UI   │  │
│  │   Watcher   │───▶│  (popover)     │  │
│  └─────────────┘    └───────┬────────┘  │
│         │                   │           │
│         ▼                   ▼           │
│  ┌─────────────┐    ┌────────────────┐  │
│  │  SQLite DB  │    │  Search Engine │  │
│  │  (GRDB.swift│    │  (FTS5 full-   │  │
│  │   + FTS5)   │    │  text search)  │  │
│  └─────────────┘    └───────┬────────┘  │
└──────────────────────────────┼──────────┘
                               │ on-device
                               ▼
                    ┌─────────────────────┐
                    │ Apple NLEmbedding   │
                    │ (Local Semantic     │
                    │      Search)        │
                    └─────────────────────┘
```

## 📦 Requirements

- **macOS 14.0** (Sonoma) or later
- **Xcode 16.3+** (Swift 6.1 or later) on macOS; the app remains in Swift 5 language mode
- [GRDB.swift](https://github.com/groue/GRDB.swift) (resolved automatically via SPM)

## 🚀 Getting Started

### Install with Homebrew

```bash
brew install --cask soulsniper-v2/tap/clipstash
```

> **Gatekeeper note:** ClipStash is currently distributed without Apple Developer ID signing/notarization. Installs from the Homebrew tap remove quarantine automatically. If you launch the app from a downloaded DMG and macOS blocks it, go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Clone & Build

```bash
git clone https://github.com/SoulSniper-V2/ClipStash.git
cd ClipStash
swift build --jobs 2
```

### Run in Xcode

```bash
open ClipStash.xcodeproj
# ⌘R to build and run
```

### Run from Terminal

```bash
swift run ClipStash
```

> **Note:** Both entry points set the app to accessory mode. Use the Xcode app bundle for Launch at Login and distribution; `swift run` is a development executable. SwiftPM copies the existing catalog into its resource bundle and loads its logo images directly, while Xcode compiles the full asset catalog.

### Validate a source build

```bash
swift test --jobs 2
xcodebuild -project ClipStash.xcodeproj -scheme ClipStash \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

The unsigned app is at `build/Build/Products/Release/ClipStash.app`. For a signed build, select your own development team in Xcode. The checked-in project and `project.yml` describe the same sources and assets; if you use XcodeGen, regenerate with `xcodegen generate` after changing the specification.

GitHub Actions runs the SwiftPM regression tests and unsigned Debug/Release Xcode builds on macOS 26 with Xcode 26.6, and checks that the app contains its compiled assets. Tests use isolated in-memory databases. They do not exercise the system clipboard, Accessibility permissions, Launch at Login, or the visible UI; smoke-test those on a Mac before a release.

## ⌨️ Usage

| Action | Shortcut |
|---|---|
| Toggle ClipStash | `⌥V` |
| Search clips | Just start typing |
| Navigate clips | `↑` / `↓` |
| Copy selected clip | `↵` Enter |
| Close popover | `Esc` |
| Pin / Delete clip | Right-click context menu |

> The current global keyboard monitor requires Accessibility permission for ClipStash under **System Settings → Privacy & Security → Accessibility**. Its global shortcut can also reach the foreground app. The menu bar button works independently of that permission.

## ⚙️ Settings

- **Launch at Login** — Start ClipStash automatically when you sign in
- **Capture from Password Managers** — Allow or block history capture from sensitive apps
- **Keep Clipboard History** — Automatically prune non-pinned clips after 7 days, 30 days, or never
- **Semantic Search** — Uses Apple `NLEmbedding` locally with no account required

## 🗂 Project Structure

```
Sources/
├── App/
│   ├── ClipStashApp.swift           # @main entry, Settings window
│   └── AppDelegate.swift            # NSStatusItem + NSPopover
├── Models/
│   ├── ClipItem.swift               # GRDB record model
│   └── ContentType.swift            # Content type detection
├── Database/
│   ├── AppDatabase.swift            # SQLite setup + migrations
│   └── ClipRepository.swift         # CRUD + FTS5 search
├── Services/
│   ├── ClipboardWatcher.swift       # NSPasteboard polling + blocklist
│   ├── HotkeyManager.swift          # Global ⌥V hotkey
│   ├── EmbeddingService.swift       # Apple NLEmbedding integration
├── Views/
│   ├── PopoverContentView.swift     # Main popover container
│   ├── ClipListView.swift           # Scrollable clip list
│   ├── ClipRowView.swift            # Individual clip row
│   ├── SearchBarView.swift          # Search input
│   └── EmptyStateView.swift         # Zero-state view
├── ViewModels/
│   └── ClipListViewModel.swift      # Observable view model
└── Utilities/
    ├── DateFormatter+Ext.swift      # Relative timestamps
    ├── NSRunningApplication+Ext.swift
    └── String+Ext.swift             # Truncation helpers
```

## 🔒 Privacy

By default, ClipStash captures content identically from all applications. However, if you'd like to disable capturing from password managers, you can easily toggle this off in the Settings. When disabled, ClipStash skips a capture if one of the following apps is frontmost at the polling tick:

- 1Password (`com.1password.1password`, `com.agilebits.onepassword7`)
- LastPass (`com.lastpass.LastPass`)
- Bitwarden (`com.bitwarden.desktop`)
- Dashlane (`com.dashlane.Dashlane`)
- KeePassXC (`org.keepassxc.keepassxc`)
- macOS Keychain Access (`com.apple.keychainaccess`)
- Enpass (`in.sinew.Enpass-Desktop`)

This check uses the foreground app, not a guaranteed clipboard producer identity. Switching apps before the next polling tick, or copying through a browser extension, can bypass it. Do not rely on this setting to exclude every sensitive copy.

All data is stored locally in `~/Library/Application Support/ClipStash/history.db`. Nothing leaves your machine.

## 🗺 Roadmap

### V2 — AI Layer
- [x] Native on-device semantic search via Apple's `NLEmbedding`
- [ ] Smart collections / filtered views

### V3 — Power Features
- [ ] Snippets with custom trigger keywords
- [ ] iCloud sync across Macs
- [ ] Settings UI for privacy blocklist
- [ ] Customizable keyboard shortcuts

## 🛠 Dependencies

| Package | Purpose |
|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | Type-safe SQLite with `ValueObservation` for live UI updates |

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ❤️ using Swift, SwiftUI, and GRDB</sub>
</p>
