// Made by Lumaa

import Foundation
import AppIntents

/// Play/pause actions offered to the Control Center widget and Siri.
///
/// Deliberately NOT a `String` raw-value enum: Cider 4 collapsed v1's
/// `playback/playpause` / `playback/play` / `playback/pause` into a single
/// `playback/toggle`, so three cases sharing one raw value would not compile.
/// The endpoint is resolved per API version instead.
enum PlaybackEnum: String, CaseIterable, AppEnum {
    case toggle
    case play
    case pause

    static var caseDisplayRepresentations: [PlaybackEnum : DisplayRepresentation] {
        [
            .toggle: DisplayRepresentation(stringLiteral: "Toggle"),
            .play: DisplayRepresentation(stringLiteral: "Play"),
            .pause: DisplayRepresentation(stringLiteral: "Pause")
        ]
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Action"

    /// v2 has only `playback/toggle`; v1 had distinct play/pause endpoints.
    func endpoint(apiVersion: String) -> String {
        guard apiVersion == "v2" else {
            switch self {
            case .play:   return "playback/play"
            case .pause:  return "playback/pause"
            case .toggle: return "playback/playpause"
            }
        }
        return "playback/toggle"
    }
}