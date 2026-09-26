# Thread

Thread is a small native macOS working-memory prosthetic. It keeps one intention visible at the top of the screen, reminds you after context switches, and lets you park and resume the apps and recent documents around that intention.

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

## Shortcuts

- Command–Shift–N: focus a new thread
- Command–Shift–P: park the active thread
- Command–Shift–Return: complete the active thread

Shortcuts are app menu commands. Thread uses only public macOS APIs and stores state locally in UserDefaults. Resuming launches captured apps and opens recent local documents that still exist.
