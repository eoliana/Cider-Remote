// Made for the sideloaded Cider Remote build

import SwiftUI

/// A `ButtonStyle` that gives visible press feedback: a quick scale-down pop
/// plus a highlight behind the glyph. Every transport button used
/// `.buttonStyle(.plain)`, which draws no pressed state at all, so a tap was
/// indistinguishable from a miss.
///
/// `configuration.isPressed` alone proved unreliable here because the player
/// view is rebuilt on every playback-time tick, and the press could be torn
/// down between ticks before it drew. So the style owns its own press state
/// with `@GestureState`, which stays pinned for exactly as long as the finger
/// is down and is independent of how often the parent re-renders.
struct CiderPressableButtonStyle: ButtonStyle {
    /// Peak shrink on press. Small enough to feel like a physical button,
    /// large enough to register on a static-looking screen.
    var scale: CGFloat = 0.88
    var dim: Double = 0.55

    /// Whether to draw the round highlight behind the glyph.
    var showsHighlight: Bool = true

    @GestureState private var pressing: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let isDown: Bool = pressing || configuration.isPressed

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
            .animation(.spring(response: 0.16, dampingFraction: 0.5), value: isDown)
            .contentShape(Rectangle())
            // Independent of Button's own tap handling, so the visual state
            // lands even if the action runs first.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressing) { _, state, _ in state = true }
            )
    }
}

extension ButtonStyle where Self == CiderPressableButtonStyle {
    /// Convenience so call sites read as `.ciderPressable()`.
    static var ciderPressable: CiderPressableButtonStyle { .init() }

    /// Stronger pop, for the large transport controls.
    static var ciderTransport: CiderPressableButtonStyle {
        .init(scale: 0.78, dim: 0.45)
    }
}