<p align="center">
  <img src="https://img.icons8.com/sf-regular-filled/96/58A6FF/clipboard.png" width="80" alt="ClipStash Icon"/>
</p>

<h1 align="center">ClipStash</h1>

<p align="center">
  <strong>A premium macOS clipboard manager with AI-powered search.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-blue?style=flat-square&logo=apple" alt="macOS 14+"/>
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" alt="Swift 5.9"/>
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
                               │ shell out
                               ▼
                    ┌─────────────────────┐
                    │ Apple NLEmbedding   │
                    │ (Local Semantic     │
                    │      Search)        │
                    └─────────────────────┘
```

## 📦 Requirements

- **macOS 14.0** (Sonoma) or later
- **Xcode 16+** or Swift 5.9+ toolchain
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
swift build
```

### Run in Xcode

```bash
open ClipStash.xcodeproj
# ⌘R to build and run
```

### Run from Terminal

```bash
swift run
```

> **Note:** For the full menu-bar-only experience (no Dock icon), build and run via Xcode. The `swift run` binary doesn't have the `LSUIElement` Info.plist flag embedded.

## ⌨️ Usage

| Action | Shortcut |
|---|---|
| Toggle ClipStash | `⌥V` |
| Search clips | Just start typing |
| Navigate clips | `↑` / `↓` |
| Copy selected clip | `↵` Enter |
| Close popover | `Esc` |
| Pin / Delete clip | Right-click context menu |

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

By default, ClipStash captures content identically from all applications. However, if you'd like to disable capturing from password managers, you can easily toggle this off in the Settings. When disabled, the following apps are actively ignored:

- 1Password (`com.1password.1password`, `com.agilebits.onepassword7`)
- LastPass (`com.lastpass.LastPass`)
- Bitwarden (`com.bitwarden.desktop`)
- Dashlane (`com.dashlane.Dashlane`)
- KeePassXC (`org.keepassxc.keepassxc`)
- macOS Keychain Access (`com.apple.keychainaccess`)
- Enpass (`in.sinew.Enpass-Desktop`)

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
