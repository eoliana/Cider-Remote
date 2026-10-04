// Made for the sideloaded Cider Remote build

import Foundation

/// Snapshot of what is playing, shared from the app to the widget extension
/// through the App Group's UserDefaults.
///
/// The widget extension cannot talk to Cider directly (App Intents can, but a
/// home-screen widget's timeline refresh is too slow and rate-limited for that),
/// so the app publishes the current track here whenever it changes and the
/// widget renders from it.
///
/// This type lives under "Cider Remote/" on purpose: that synchronized group is
/// a member of BOTH the app target and the widget extension target, so both
/// sides see the same definition. Files under NowPlaying/ are extension-only.
struct SharedNowPlaying: Codable, Equatable {
    var title: String
    var artist: String
    var album: String
    var artworkURL: String?
    var lyricLine: String?
    var isPlaying: Bool
    var deviceName: String
    var connectionMethod: String
    var host: String
    var token: String
    /// True when Cider 4's v2 API is in use, so the widget's controls hit the
    /// right endpoints.
    var apiVersion: String

    var artwork: URL? { artworkURL.flatMap(URL.init(string:)) }

    static let storageKey = "sharedNowPlaying"
    static let empty = SharedNowPlaying(
        title: "", artist: "", album: "", artworkURL: nil, lyricLine: nil,
        isPlaying: false, deviceName: "", connectionMethod: "lan",
        host: "", token: "", apiVersion: "v2"
    )

    /// `UserDefaults.main` falls back to .standard when the App Group is not
    /// provisioned, so this never traps on an unsigned install.
    static func load() -> SharedNowPlaying {
        guard let data = UserDefaults.main.data(forKey: storageKey) else { return .empty }
        return (try? JSONDecoder().decode(SharedNowPlaying.self, from: data)) ?? .empty
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.main.set(data, forKey: Self.storageKey)
        // Also .standard, so the app can read its own snapshot back on launch.
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func clear() {
        UserDefaults.main.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}