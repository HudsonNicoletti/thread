import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private var cancellables: Set<AnyCancellable> = []
    private var isHovered = false

    private let notchWidth: CGFloat = 220
    private let collapsedWidth: CGFloat = 268
    private let expandedWidth: CGFloat = 480

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
        panel.contentView = NSHostingView(rootView: NotchIndicator(controller: controller) { [weak self] hovered in
            self?.setHovered(hovered)
        })

        controller.$active.combineLatest(controller.$reminderText)
            .sink { [weak self] active, reminder in self?.update(active: active, reminder: reminder) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.position() }
            .store(in: &cancellables)
    }

    private func update(active: WorkThread?, reminder _: String?) {
        guard active != nil else {
            panel.orderOut(nil)
            return
        }
        position()
        panel.orderFrontRegardless()
    }

    private func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        position(animated: true)
    }

    private func position(animated: Bool = false) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.frame
        let width = isHovered ? expandedWidth : collapsedWidth
        let height = max(screen.safeAreaInsets.top, 32)
        // ponytail: public APIs expose notch depth, not width; keep the 220-point width as the single hardware calibration knob.
        let target = NSRect(x: frame.midX - notchWidth / 2, y: frame.maxY - height, width: width, height: height)
        guard animated else {
            panel.setFrame(target, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.38
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(target, display: true)
        }
    }
}
