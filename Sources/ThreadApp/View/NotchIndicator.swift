import AppKit
import SwiftUI

struct NotchIndicator: View {
    @ObservedObject var controller: ThreadController

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: (NSScreen.main ?? NSScreen.screens.first)?.safeAreaInsets.top ?? 0)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 7, height: 7)
                Text(controller.indicatorTitle)
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
        .accessibilityLabel(controller.indicatorTitle)
    }
}
