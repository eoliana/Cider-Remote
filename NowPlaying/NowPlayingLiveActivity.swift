// Made by Lumaa

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            expandView(using: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center, priority: 2.0) {
                    expandView(using: context, dynamicIsland: true)
                }

                DynamicIslandExpandedRegion(.leading) {
                    self.artwork(using: context)
                        .frame(width: 65, height: 65, alignment: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 3.0))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    playBtn(using: context)
                        .frame(height: 65, alignment: .center)
                }
            } compactLeading: {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
            } compactTrailing: {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(Color.white)
            } minimal: {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
            }
            .keylineTint(Color.cider)
        }
    }

    /// The artwork view. Uses the inline bytes when the host app already
    /// downloaded them, and otherwise falls back to fetching the URL —
    /// `Image("Logo")` was showing a generic glyph because the extension has
    /// no artwork of its own and the URL was never consulted.
    @ViewBuilder
    private func artwork(using context: ActivityViewContext<NowPlayingLiveActivity.NowPlayingAttributes>) -> some View {
        if let data: Data = context.state.trackInfo.artworkData,
           let ui: UIImage = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        } else if let url: URL = context.state.trackInfo.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    fallbackArtwork
                default:
                    fallbackArtwork.opacity(0.4)
                }
            }
        } else {
            fallbackArtwork
        }
    }

    @ViewBuilder
    private var fallbackArtwork: some View {
        ZStack {
            Color.black.opacity(0.6)
            Image(systemName: "music.note")
                .resizable()
                .scaledToFit()
                .padding(8)
                .foregroundStyle(Color.white.opacity(0.8))
        }
    }

    @ViewBuilder
    private func expandView(using context: ActivityViewContext<NowPlayingAttributes>, dynamicIsland: Bool = false) -> some View {
        HStack {
            if !dynamicIsland {
                self.artwork(using: context)
                    .frame(width: 40, height: 40, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 3.0))
            }

            VStack(alignment: .leading) {
                Text(context.state.trackInfo.title)
                    .font(.body.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.white)

                Text(context.state.trackInfo.artist)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.gray)

                // Sideloaded build: show the current lyric line under the
                // artist, the way Apple Music's own Live Activity does. Off by
                // default in the UI so the plain title layout is still one tap
                // away.
                if let line: String = context.state.trackInfo.lyricLine, !line.isEmpty {
                    Text(line)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(Color.cider.opacity(0.9))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, dynamicIsland ? 0 : nil)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicIsland {
                playBtn(using: context)
            }
        }
        .padding(.horizontal, dynamicIsland ? 0 : nil)
        .padding(.vertical, dynamicIsland ? 0 : 7.5)
    }

    @ViewBuilder
    private func playBtn(using context: ActivityViewContext<NowPlayingLiveActivity.NowPlayingAttributes>) -> some View {
        Button(intent: TogglePlayButtonIntent(device: .init(from: context.attributes.device))) {
            Image(systemName: "playpause.fill")
                .font(.title)
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artworkUnusedRemoved(using context: ActivityViewContext<NowPlayingLiveActivity.NowPlayingAttributes>) -> some View {
        EmptyView()
    }

    struct NowPlayingAttributes: ActivityAttributes {
        let device: Device

        public struct ContentState: Codable, Hashable {
            public func hash(into hasher: inout Hasher) {
                hasher.combine(trackInfo.id)
            }

            var trackInfo: LiveActivityManager.DisplayingTrack
        }
    }
}
