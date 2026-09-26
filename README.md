# Thread

Thread is a menu-bar-only native macOS working-memory prosthetic. It keeps one intention visible at the notch, reminds you after context switches, and lets you create, park, resume, complete, and delete threads from the menu bar.

## Run

```sh
swift run Thread
```

Build a signed local app bundle:

```sh
chmod +x scripts/build-app.sh
scripts/build-app.sh
open .build/Thread.app
```

Requires macOS 14 or newer.

Thread has no Dock app or standalone window. It uses only public macOS APIs and stores state locally in UserDefaults. Resuming launches captured apps and opens recent local documents that still exist.

## Structure

- `Model/` — thread and captured-context data
- `Controller/` — state, persistence, context restoration, and notch panel control
- `View/` — menu-bar and notch SwiftUI views
- `ThreadApp.swift` — application composition
