// Made for the sideloaded Cider Remote build

import SwiftUI
import WidgetKit

/// Home-screen widget: full album art, transport controls, and the current
/// lyric line. Reads its state from `SharedNowPlaying`, which the app publishes
/// through the App Group.
struct CiderNowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "sh.cider.CiderRemote.NowPlayingWidget", provider: CiderTimelineProvider()) { entry in
            CiderWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.black, Color(red: 0.08, green: 0.07, blue: 0.11)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Now Playing")
        .description("Album art, transport controls and the current lyric line.")
        // Every system widget is capped at ~30-40 refreshes/day.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CiderTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedNowPlaying
}

struct CiderTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CiderTimelineEntry {
        CiderTimelineEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (CiderTimelineEntry) -> Void) {
        completion(CiderTimelineEntry(date: Date(), snapshot: SharedNowPlaying.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CiderTimelineEntry>) -> Void) {
        let entry = CiderTimelineEntry(date: Date(), snapshot: SharedNowPlaying.load())
        // The app reloads timelines itself whenever the track or lyric line
        // changes; this is only a floor so the widget is never permanently
        // stale if the app has been killed.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CiderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: SharedNowPlaying

    private var isCompact: Bool { family == .systemSmall }

    var body: some View {
        if snapshot.title.isEmpty {
            emptyState
        } else {
            content
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
            Text("Nothing playing")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(alignment: .top, spacing: 10) {
                artwork

                if !isCompact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(snapshot.artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                        if !snapshot.album.isEmpty {
                            Text(snapshot.album)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let line = snapshot.lyricLine, !line.isEmpty, !isCompact {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(Color("CiderColor"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }

            controls
        }
        .padding(2)
    }

    private var artwork: some View {
        Group {
            if let url = snapshot.artwork {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    default:
                        ZStack {
                            Color.white.opacity(0.08)
                            ProgressView()
                        }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: isCompact ? 64 : 52, height: isCompact ? 64 : 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "music.note")
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var controls: some View {
        HStack(spacing: isCompact ? 14 : 18) {
            if let device = deviceEntity {
                Button(intent: WidgetRewindIntent(device: device)) {
                    Image(systemName: "backward.fill").font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                Button(intent: WidgetPlayPauseIntent(device: device)) {
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                Button(intent: WidgetSkipIntent(device: device)) {
                    Image(systemName: "forward.fill").font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            } else {
                // No paired device: still show the artwork state rather than
                // three dead buttons.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var deviceEntity: DeviceEntity? {
        guard !snapshot.host.isEmpty, !snapshot.token.isEmpty else { return nil }
        return DeviceEntity(
            name: snapshot.deviceName.isEmpty ? "Cider" : snapshot.deviceName,
            token: snapshot.token,
            host: snapshot.host,
            connectionMethod: snapshot.connectionMethod,
            apiVersion: snapshot.apiVersion,
            isActive: true,
            isPlaying: snapshot.isPlaying
        )
    }
}