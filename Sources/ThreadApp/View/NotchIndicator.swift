import AppKit
import SwiftUI

struct NotchIndicator: View {
    @ObservedObject var controller: ThreadController
    let onHoverChange: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 220)
            pulsingDot
            if controller.indicatorHovered {
                Text(controller.indicatorTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Spacer(minLength: 10)
        }
        .padding(.trailing, 12)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(
            bottomTrailingRadius: 10,
            style: .continuous
        ))
        .accessibilityLabel(controller.indicatorTitle)
        .overlay(HoverTrackingView { hovered in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                controller.indicatorHovered = hovered
            }
            onHoverChange(hovered)
        })
    }

    @ViewBuilder
    private var pulsingDot: some View {
        if reduceMotion {
            dot
        } else {
            PhaseAnimator([false, true]) { dimmed in
                dot
                    .scaleEffect(dimmed ? 0.82 : 1)
                    .opacity(dimmed ? 0.35 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.2)
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(Color.cyan)
            .frame(width: 8, height: 8)
    }
}

private struct HoverTrackingView: NSViewRepresentable {
    let onHover: (Bool) -> Void

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ view: HoverTrackingNSView, context: Context) {
        view.onHover = onHover
    }
}

private final class HoverTrackingNSView: NSView {
    var onHover: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}
