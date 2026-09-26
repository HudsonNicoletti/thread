import AppKit
import SwiftUI

@main
struct ThreadApp: App {
    @StateObject private var controller: ThreadController
    private let panelController: NotchPanelController

    init() {
        let controller = ThreadController()
        _controller = StateObject(wrappedValue: controller)
        panelController = NotchPanelController(controller: controller)
        NSApp.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Thread", systemImage: controller.active == nil ? "circle" : "circle.dotted") {
            ThreadView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}
