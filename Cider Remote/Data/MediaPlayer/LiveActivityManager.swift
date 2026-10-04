// Made by Lumaa

import SwiftUI
import WidgetKit
import ActivityKit
import LyricsStudioKit

class LiveActivityManager {
    @AppStorage("alertLiveActivity") private var alertLiveActivity: Bool = false

	/// Sideloaded-only: mirror the current lyric line into the Live Activity.
	/// The App Store build cannot ship this (Apple Music's own activity already
	/// does it), so it is opt-in and defaults to on here.
	@AppStorage("liveActivityLyrics") private var showLyricsInActivity: Bool = true

    static let shared: LiveActivityManager = .init()

    var device: Device? = nil

	/// trackID -> timed lyric lines, fetched once per track.
	private var lyricCache: [String: [LyricLine]] = [:]
	private var lyricFetchInFlight: Set<String> = []

    var lastActivity: Activity<NowPlayingLiveActivity.NowPlayingAttributes>? = nil
    var activity: Activity<NowPlayingLiveActivity.NowPlayingAttributes>? {
        return Activity<NowPlayingLiveActivity.NowPlayingAttributes>.activities.first
    }

    func startActivity(using track: Track) {
        guard let device else { return }

        if activity != nil {
            Task {
                await self.updateActivity(with: track)
            }
            return
        }

        Task {
            let display: DisplayingTrack = Self.DisplayingTrack(from: track)
            let cont: NowPlayingLiveActivity.NowPlayingAttributes.ContentState = .init(
                trackInfo: display
            )
            
            if #available(iOS 16.2, *) {
                self.lastActivity = try Activity
                    .request(
                        attributes: .init(device: device),
                        content: .init(state: cont, staleDate: .now.addingTimeInterval(pow(10, 3) * 900), relevanceScore: 9.0)
                    )
            } else {
                self.lastActivity = try Activity.request(attributes: .init(device: device), contentState: cont)
            }
            print("STARTED LIVE ACTIVITY")
        }
    }

    func updateActivity(with content: NowPlayingLiveActivity.NowPlayingAttributes.ContentState) async {
        guard let activity else { return }

        await activity
            .update(
                .init(state: content, staleDate: nil),
                alertConfiguration: alertLiveActivity ? .init(
                    title: "Cider Remote",
                    body: "Now Playing: \(content.trackInfo.title) by \(content.trackInfo.artist)",
                    sound: .default
                ) : nil
            )
        print("UPDATED1 LIVE ACTIVITY")
    }

    func updateActivity(with track: Track) async {
        guard let activity else { return }

        let display: DisplayingTrack = Self.DisplayingTrack(from: track)
        let state: NowPlayingLiveActivity.NowPlayingAttributes.ContentState = .init(
            trackInfo: display
        )

        await activity
            .update(.init(state: state, staleDate: nil),
                alertConfiguration: alertLiveActivity ? .init(
                    title: "Cider Remote",
                    body: "Now Playing: \(track.title) by \(track.artist)",
                    sound: .default
                ) : nil
            )
        print("UPDATED2 LIVE ACTIVITY")
    }

    /// The lyric line that should be on screen at `time`, if any.
    /// Blank lines are skipped so the activity does not flicker to blank
    /// between instrumental gaps.
    func activeLyric(for trackID: String, at time: Double) -> String? {
        guard showLyricsInActivity, let lines = lyricCache[trackID], !lines.isEmpty else { return nil }
        guard let line = lines.last(where: { $0.timestamp <= time }) else { return nil }
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Fetch lyrics for a track once and keep them for the activity.
    func prepareLyrics(for track: Track, device: Device) {
        guard showLyricsInActivity else { return }
        guard !track.catalogId.isEmpty else { return }
        guard lyricCache[track.id] == nil, !lyricFetchInFlight.contains(track.id) else { return }

        lyricFetchInFlight.insert(track.id)
        Task {
            let lines = await Self.fetchLyricLines(track: track, device: device)
            self.lyricFetchInFlight.remove(track.id)
            if let lines, !lines.isEmpty {
                self.lyricCache[track.id] = lines
            }
        }
    }

    /// Push the current track's active lyric line into the running activity.
    /// Cheap enough to call on every playback-time tick.
    func syncLyricLine(track: Track, at time: Double) async {
        guard showLyricsInActivity, activity != nil else { return }
        guard let line = activeLyric(for: track.id, at: time) else { return }
        // Already showing this line: ActivityKit updates are rate-limited and
        // each one can get the activity throttled.
        guard activity?.content.state.trackInfo.lyricLine != line else { return }

        var state = activity!.content.state
        state.trackInfo.lyricLine = line
        await activity!.update(.init(state: state, staleDate: nil))
    }

    private static func fetchLyricLines(track: Track, device: Device) async -> [LyricLine]? {
        // Same two providers LyricsView tries, in the same order.
        do {
            let result: StudioLyricResponse = try await LyricsStudio.fetchLyrics(for: MusicItemID(rawValue: track.catalogId))
            guard let data = result.ttml.data(using: .utf8) else { return nil }
            let xml = XMLParser(data: data)
            let parsed = Parser(provider: .studio)
            xml.delegate = parsed
            guard xml.parse(), !parsed.lyrics.isEmpty else { return nil }
            return parsed.lyrics
        } catch {
            // Fall through to the AM lyrics below.
        }

        do {
            // Same storefront lookup LyricsView does before asking AM.
            guard let data = try await device.runAppleMusicAPI(path: "/v1/me/storefront?limit=1") as? [[String: Any]],
                  let storefront = (data.first?["id"] as? String) else { return nil }
            let resp = try await device.runAppleMusicAPI(path: "/v1/catalog/\(track.catalogId)/lyrics?extend=ttml&l=\(storefront)")
            guard let ttml = Self.extractTTML(from: resp) else { return nil }
            let xml = XMLParser(data: ttml)
            let parsed = Parser(provider: .appleMusic)
            xml.delegate = parsed
            guard xml.parse() else { return nil }
            return parsed.lyrics
        } catch {
            return nil
        }
    }

    /// The runAppleMusicAPI wrapper hands back a nested dictionary; dig the
    /// TTML string out of it without caring which level it came back at.
    private static func extractTTML(from value: Any) -> Data? {
        if let str = value as? String { return str.data(using: .utf8) }
        if let dict = value as? [String: Any] {
            for key in ["ttml", "lyrics", "data"] {
                if let nested = dict[key] {
                    if let found = extractTTML(from: nested) { return found }
                }
            }
        }
        if let arr = value as? [Any] {
            for item in arr {
                if let found = extractTTML(from: item) { return found }
            }
        }
        return nil
    }

    func stopActivity() {
        guard let activity else { return }

        Task {
            if #available(iOS 16.2, *) {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
            print("STOPPED LIVE ACTIVITY")
        }
    }

    struct DisplayingTrack: Identifiable, Codable, Equatable {
        let id: String
        let title: String
        let artist: String
        let album: String
        let artworkURL: URL?
        /// Currently-singing line, shown as the activity's subtitle.
        var lyricLine: String?
        /// Set once the artwork bytes are in hand. ActivityKit content state
        /// must stay under its size cap, so this is a URL the extension
        /// re-fetches rather than an inline Data blob.
        var artworkData: Data?

        init(title: String, artist: String, album: String = "", artworkURL: URL? = nil) {
            self.id = UUID().uuidString
            self.title = title
            self.artist = artist
            self.album = album
            self.artworkURL = artworkURL
            self.lyricLine = nil
            self.artworkData = nil
        }

        init(from track: Track) {
            self.id = track.id
            self.title = track.title
            self.artist = track.artist
            self.album = track.album
            self.artworkURL = URL(string: track.artwork)
            self.lyricLine = nil
            self.artworkData = track.artworkData.isEmpty ? nil : track.artworkData
        }

        func getArtworkData() async -> Data? {
            guard let artworkURL else { return nil }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                return data
            } catch {
                print("Error loading image: \(error)")
            }
            return nil
        }
    }
}

