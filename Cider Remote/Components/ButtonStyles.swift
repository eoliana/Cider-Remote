// Made for the sideloaded Cider Remote build

import SwiftUI

/// A `ButtonStyle` that gives visible press feedback: a quick scale-down pop
/// plus a brief highlight. Every transport button used `.buttonStyle(.plain)`,
/// which draws no pressed state at all, so a tap was indistinguishable from a
/// miss.
///
/// Scale settles back with a spring rather than a plain ease so the rebound
/// reads as a "pop" instead of a fade.
struct CiderPressableButtonStyle: ButtonStyle {
    /// Peak shrink on press. Small enough to feel like a physical button,
    /// large enough to register on a static-looking screen.
    var scale: CGFloat = 0.88
    var dim: Double = 0.6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? dim : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CiderPressableButtonStyle {
    /// Convenience so call sites read as `.ciderPressable()`.
    static var ciderPressable: CiderPressableButtonStyle { .init() }

    /// Slightly stronger pop, for the large transport controls.
    static var ciderTransport: CiderPressableButtonStyle {
        .init(scale: 0.82, dim: 0.5)
    }
}