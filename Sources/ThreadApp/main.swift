import AppKit
import Combine
import SwiftUI

struct CapturedContext: Codable, Hashable {
    var appBundleIDs: [String] = []
    var documentPaths: [String] = []
}

struct WorkThread: Codable, Identifiable, Hashable {
    let id: UUID
    var intention: String
    var note: String
    var createdAt: Date
    var finishedAt: Date?
    var context: CapturedContext
}

@MainActor
final class ThreadStore: ObservableObject {
    @Published var active: WorkThread?
    @Published var parked: [WorkThread] = []
    @Published var completed: [WorkThread] = []
    @Published var draft = ""
    @Published var note = ""
    @Published var reminderText: String?

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

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private var cancellables: Set<AnyCancellable> = []

    init(store: ThreadStore) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: NotchIndicator(store: store))

        store.$active.combineLatest(store.$reminderText)
            .sink { [weak self] active, reminder in self?.update(active: active, reminder: reminder) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.position() }
            .store(in: &cancellables)
    }

    private func update(active: WorkThread?, reminder: String?) {
        guard active != nil else {
            panel.orderOut(nil)
            return
        }
        let width: CGFloat = reminder == nil ? 220 : 360
        let visibleHeight: CGFloat = reminder == nil ? 32 : 46
        let notchDepth = (NSScreen.main ?? NSScreen.screens.first)?.safeAreaInsets.top ?? 0
        panel.setContentSize(NSSize(width: width, height: notchDepth + visibleHeight))
        position()
        panel.orderFrontRegardless()
    }

    private func position() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.frame
        let x = frame.midX - panel.frame.width / 2
        // ponytail: the black background may sit behind the hardware; controls never do. Starting at screen top removes the menu-bar seam.
        let y = frame.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct NotchIndicator: View {
    @ObservedObject var store: ThreadStore

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: (NSScreen.main ?? NSScreen.screens.first)?.safeAreaInsets.top ?? 0)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 7, height: 7)
                Text(store.indicatorTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(
            bottomLeadingRadius: 12,
            bottomTrailingRadius: 12,
            style: .continuous
        ))
        .accessibilityLabel(store.indicatorTitle)
    }
}

struct ThreadView: View {
    @ObservedObject var store: ThreadStore
    @FocusState private var focusDraft: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Thread").font(.title.bold())
                        Text("Remember what you were doing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let active = store.active {
                        activeCard(active)
                    } else {
                        newThreadForm
                    }

                    if !store.parked.isEmpty {
                        section("Parked") {
                            ForEach(store.parked) { thread in
                                threadRow(thread, action: "Resume") { store.resume(thread) }
                            }
                        }
                    }

                    if !store.completed.isEmpty {
                        section("Done") {
                            ForEach(store.completed.prefix(5)) { thread in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text(thread.intention).lineLimit(1)
                                    Spacer()
                                    if let date = thread.finishedAt {
                                        Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            Divider()
            HStack {
                Text("Local only").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit Thread") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .padding(12)
        }
        .frame(width: 380, height: 520)
    }

    private var newThreadForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("What are you doing now?", text: $store.draft)
                .textFieldStyle(.roundedBorder)
                .focused($focusDraft)
                .onSubmit(store.setIntention)
                .accessibilityLabel("Current intention")
            TextField("Optional note", text: $store.note)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Optional note")
            Button("Start Thread", action: store.setIntention)
                .buttonStyle(.borderedProminent)
                .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func activeCard(_ thread: WorkThread) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current thread", systemImage: "circle.dotted")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(thread.intention).font(.title2.weight(.semibold))
            if !thread.note.isEmpty { Text(thread.note).foregroundStyle(.secondary) }
            HStack {
                Button("Park & New", action: store.park)
                Button("Complete", action: store.complete).buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func threadRow(_ thread: WorkThread, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.intention).lineLimit(1)
                if !thread.note.isEmpty { Text(thread.note).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            Button(action, action: perform)
            Button(role: .destructive) { store.removeParked(thread) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(thread.intention)")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

@main
struct ThreadApp: App {
    @StateObject private var store: ThreadStore
    private let panelController: NotchPanelController

    init() {
        let store = ThreadStore()
        _store = StateObject(wrappedValue: store)
        panelController = NotchPanelController(store: store)
        NSApp.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Thread", systemImage: store.active == nil ? "circle" : "circle.dotted") {
            ThreadView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
