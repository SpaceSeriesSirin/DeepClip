# DeepClip v1.0.0

The first public release of **DeepClip** — a smart clipboard manager for macOS that goes
beyond simple copy-paste. It lives in your menu bar, understands what you copy, and stays
out of your way.

## Highlights

- **Smart clipboard history** — Automatically captures text, images, URLs, terminal
  commands, and code snippets, with rule-based classification and automatic URL grouping
  by domain.
- **AI-powered intelligence (optional)** — Semantic search via embeddings, LLM
  classification, auto-generated titles/summaries, intent recognition, format cleaning,
  smart dedup, and smart conversion (Markdown ↔ plain text, JSON, URL/Base64). Works with
  OpenAI, llama.cpp, or Ollama through a unified interface — every feature is toggleable.
- **Quick Panel & global hotkey** — Summon a floating overlay from anywhere with a
  configurable hotkey and paste instantly (auto-paste via simulated ⌘V) without switching
  apps.
- **Pin, collect & never lose what matters** — Pin important items so they survive
  cleanup, and back up everything with full JSON import/export.
- **Menu-bar-only, minimal footprint** — No Dock icon, optional launch at login via
  `SMAppService`, and a clean SwiftUI interface.

## System Requirements

- macOS 13 Ventura or later
- Apple Silicon (arm64) or Intel Mac
- (Optional) An OpenAI API key, or a local llama.cpp / Ollama server, to enable AI features

## Installation

1. Download `DeepClip.zip` from this release.
2. Unzip it (double-click in Finder) to get `DeepClip.app`.
3. Move `DeepClip.app` to your **Applications** folder.
4. This build is **ad-hoc signed** (not notarized). On first launch macOS Gatekeeper will
   block it, so open it once with a right-click:
   - Right-click (or Control-click) `DeepClip.app` → **Open** → **Open** in the dialog.
   - Alternatively, run in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/DeepClip.app
     ```
5. DeepClip launches into the **menu bar** (there is no Dock icon). Click the menu-bar
   icon to open it, and press your global hotkey to summon the Quick Panel.
6. To enable AI features, open **Settings** and configure your preferred backend
   (OpenAI / llama.cpp / Ollama).

---

*Version 1.0.0 · Bundle ID `com.deepclip.app` · Built with SwiftUI and Swift Package Manager.*
