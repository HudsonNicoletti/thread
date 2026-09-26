import AppKit
import Combine
import Foundation

@MainActor
final class ThreadController: ObservableObject {
    @Published var active: WorkThread?
    @Published var parked: [WorkThread] = []
    @Published var completed: [WorkThread] = []
    @Published var draft = ""
    @Published var note = ""
    @Published var reminderText: String?
    @Published var indicatorHovered = false

    private struct State: Codable {
        var active: WorkThread?
        var parked: [WorkThread]
        var completed: [WorkThread]
    }

    private let defaultsKey = "thread.state.v1"
    private var recentApps: [String] = []
    private var reminderTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?

    init() {
        restore()
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            recentApps = [bundleID]
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in self?.applicationActivated(app) }
        }
    }

    var indicatorTitle: String {
        guard let active else { return "Thread" }
        return reminderText ?? active.intention
    }

    func setIntention() {
        let intention = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intention.isEmpty else { return }
        active = WorkThread(
            id: UUID(),
            intention: intention,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: .now,
            context: captureContext()
        )
        draft = ""
        note = ""
        save()
    }

    func park() {
        guard var thread = active else { return }
        thread.context = captureContext()
        parked.insert(thread, at: 0)
        active = nil
        reminderText = nil
        save()
    }

    func complete() {
        guard var thread = active else { return }
        thread.finishedAt = .now
        completed.insert(thread, at: 0)
        completed = Array(completed.prefix(20))
        active = nil
        reminderText = nil
        save()
    }

    func resume(_ thread: WorkThread) {
        if let active { parked.insert(active, at: 0) }
        parked.removeAll { $0.id == thread.id }
        active = thread
        restoreContext(thread.context)
        save()
    }

    func removeParked(_ thread: WorkThread) {
        parked.removeAll { $0.id == thread.id }
        save()
    }

    private func applicationActivated(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else { return }
        recentApps.removeAll { $0 == bundleID }
        recentApps.insert(bundleID, at: 0)
        recentApps = Array(recentApps.prefix(6))

        guard let active,
              !active.context.appBundleIDs.isEmpty,
              !active.context.appBundleIDs.contains(bundleID) else { return }

        reminderTask?.cancel()
        reminderText = "You were working on \(active.intention)"
        reminderTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            reminderText = nil
        }
    }

    private func captureContext() -> CapturedContext {
        let documents = NSDocumentController.shared.recentDocumentURLs
            .filter { $0.isFileURL }
            .prefix(8)
            .map(\.path)
        return CapturedContext(
            appBundleIDs: Array(recentApps.prefix(6)),
            documentPaths: Array(documents)
        )
    }

    private func restoreContext(_ context: CapturedContext) {
        for bundleID in context.appBundleIDs {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { continue }
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
        for path in context.documentPaths where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        active = state.active
        parked = state.parked
        completed = state.completed
    }

    private func save() {
        let state = State(active: active, parked: parked, completed: completed)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
