// Made for the sideloaded Cider Remote build

import SwiftUI

/// A `ButtonStyle` that gives visible press feedback: a quick scale-down pop
/// plus a highlight behind the glyph. Every transport button used
/// `.buttonStyle(.plain)`, which draws no pressed state at all, so a tap was
/// indistinguishable from a miss.
///
/// Deliberately driven by `configuration.isPressed` alone. An earlier version
/// added a `simultaneousGesture(DragGesture(minimumDistance: 0))` to try to
/// hold the press across the player's per-tick re-renders; that gesture
/// swallowed the taps entirely and the transport buttons stopped responding.
/// Do not reintroduce it — if the pop is ever too brief to see, widen the
/// animation instead.
struct CiderPressableButtonStyle: ButtonStyle {
    /// Peak shrink on press. Small enough to feel like a physical button,
    /// large enough to register on a static-looking screen.
    var scale: CGFloat = 0.88
    var dim: Double = 0.55

    /// Whether to draw the round highlight behind the glyph.
    var showsHighlight: Bool = true

    /// How long the pop takes to settle. Slower = easier to actually see.
    var response: Double = 0.28

    func makeBody(configuration: Configuration) -> some View {
        let isDown: Bool = configuration.isPressed

        return configuration.label
            .scaleEffect(isDown ? scale : 1.0)
            .opacity(isDown ? dim : 1.0)
            .background {
                if showsHighlight {
                    Circle()
                        .fill(Color.white.opacity(isDown ? 0.22 : 0.0))
                        .scaleEffect(isDown ? 1.0 : 0.7)
                }
            }
            .animation(.spring(response: response, dampingFraction: 0.55), value: isDown)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == CiderPressableButtonStyle {
    /// Convenience so call sites read as `.ciderPressable()`.
    static var ciderPressable: CiderPressableButtonStyle { .init() }

    /// Stronger pop, for the large transport controls.
    static var ciderTransport: CiderPressableButtonStyle {
        .init(scale: 0.78, dim: 0.45, response: 0.32)
    }
}