import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private var cancellables: Set<AnyCancellable> = []

    init(controller: ThreadController) {
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
        panel.contentView = NSHostingView(rootView: NotchIndicator(controller: controller))

        controller.$active.combineLatest(controller.$reminderText)
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
        panel.setFrameOrigin(NSPoint(x: x, y: frame.maxY - panel.frame.height))
    }
}
