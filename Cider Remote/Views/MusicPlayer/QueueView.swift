// Made by Lumaa

import SwiftUI

struct QueueView<Content : View>: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let device: Device

    @Binding var queueItems: [Track]
    @Binding var sourceQueue: Queue?
    @Binding var currentTrack: Track?

    @State private var tappedTrack: Track? = nil
        @State private var fetchingResults: Bool = false

    	/// Already-played tracks, newest first. Empty until the user scrolls the
    	/// list up past the top of the queue.
    	@State private var playedHistory: [Track] = []
    	@State private var isLoadingHistory: Bool = false
    	@State private var didTryHistory: Bool = false

    	@State private var librarySheet: Bool = false

    @FocusState private var isSearching: Bool

    var header: () -> Content

    var body: some View {
        ZStack {
            List {
                self.header()
                    .ciderRowOptimized()

                historyView

                queueView
                    .ciderRowOptimized()
            }
            .contentMargins(.bottom, 20, for: .scrollContent)
            .contentMargins(.top, 10, for: .scrollContent)
            .ciderOptimized()
            .refreshable {
                // Pull-to-refresh on the queue doubles as "reload history".
                await self.loadHistoryIfNeeded()
            }
        }
        .foregroundStyle(.primary)
		.task {
			await fetchQueueItems()
			// Proactively load history so scrolling up shows it immediately
			// rather than needing a pull-to-refresh first.
			await loadHistoryIfNeeded()
		}
    }

    @ViewBuilder
    private var queueView: some View {
        if queueItems.count < 1 || (queueItems.count == 1 && queueItems.first?.id == currentTrack?.id) {
            ContentUnavailableView("Queue empty", systemImage: "list.number", description: Text("Your Cider queue is empty"))
        } else {
            ForEach(queueItems, id: \.id) { track in
                Button {
                    Task {
                        await playFromQueue(track)
                    }
                } label: {
                    trackRow(track, showDuration: true)
                        .ciderRowOptimized()
                }
            }
            .onDelete { set in
                guard var sourceQueue = sourceQueue else { return }

                self.queueItems.remove(atOffsets: set)
                sourceQueue.remove(set: set)

                self.sourceQueue = sourceQueue

                Task {
                    for i in set {
                        await self.removeQueue(index: i)
                    }
                }
            }
            .onMove { from, to in
                guard var sourceQueue = sourceQueue, let firstIndex = from.first else { return }

                self.queueItems.move(fromOffsets: from, toOffset: to)
                sourceQueue.move(from: from, to: to)

                self.sourceQueue = sourceQueue

                Task {
                    await self.moveQueue(from: firstIndex, to: to)
                }
            }
        }
    }

    /// Play history, revealed by scrolling up past the top of the queue.
    @ViewBuilder
    private var historyView: some View {
        if isLoadingHistory {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading history…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .listRowSeparator(.hidden)
        } else if !playedHistory.isEmpty {
            Section {
                ForEach(playedHistory, id: \.id) { track in
                    Button {
                        Task { await playFromHistory(track) }
                    } label: {
                        HStack(spacing: 12) {
                            trackRow(track, showDuration: true)
                            Image(systemName: "arrow.counterclockwise")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(CiderPressableButtonStyle())
                }
            } header: {
                Text("Recently played")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
            }
        } else if didTryHistory {
            Text("No earlier tracks in this queue")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowSeparator(.hidden)
        }
    }

    private func loadHistoryIfNeeded() async {
        guard !isLoadingHistory, playedHistory.isEmpty else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        didTryHistory = true
        do {
            self.playedHistory = try await Queue(tracks: []).fetchHistory(device: device)
        } catch {
            print("[QUEUE] history failed: \(error)")
            self.playedHistory = []
        }
    }

    /// Jumping back into history is a queue jump to an absolute index.
    private func playFromHistory(_ track: Track) async {
        guard let position = try? await device.queueIndex(of: track) else { return }
        do {
            let path: String = device.useV2 ? "queue/jump" : "playback/queue/change-to-index"
            _ = try await device.sendRequest(endpoint: path, method: "POST", body: ["index": position])
            await self.fetchQueueItems()
            self.playedHistory = []
            self.didTryHistory = false
        } catch {
            print(error)
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track, showDuration: Bool = false) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: track.artwork)) { phase in
                switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    @unknown default:
                        EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if showDuration {
                Spacer()

#if DEBUG
                if let trackIndex = sourceQueue?.firstIndex(of: track), trackIndex >= 0 {
                    Text("\(trackIndex)")
                        .font(.caption.bold())
                }
#endif

                Text(formatDuration(track.duration))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Device functions

    func moveQueue(from startIndex: Int, to destinationIndex: Int) async {
        guard let sourceQueue, startIndex != destinationIndex else { return }
        do {
			let path: String = device.useV2 ? "queue/move" : "playback/queue/move-to-position"
            _ = try await device.sendRequest(endpoint: path, method: "POST", body: ["startIndex" : startIndex + sourceQueue.offset, "destinationIndex": destinationIndex + sourceQueue.offset])
            try? await Task.sleep(nanoseconds: 500_000_000) // we don't wait, then the *fetchQueueItems* will error
            await self.fetchQueueItems()
        } catch {
            print(error)
        }
    }

    func removeQueue(index: Int) async {
        guard let sourceQueue else { return }
        do {
			let path: String = device.useV2 ? "queue/items/\(index + sourceQueue.offset)" : "playback/queue/remove-by-index"
			let method: String = device.useV2 ? "DELETE" : "POST"
            _ = try await device.sendRequest(endpoint: path, method: method, body: ["index": index + sourceQueue.offset]) // body unused in v2
        } catch {
            print(error)
        }
    }

    func playFromQueue(_ track: Track) async {
        guard let sourceQueue, let index = sourceQueue.tracks.firstIndex(where: { $0.id == track.id }) else { return }
        print("[QUEUE] play from queue")

        do {
			let path: String = device.useV2 ? "queue/jump" : "playback/queue/change-to-index"
            _ = try await device.sendRequest(endpoint: path, method: "POST", body: ["index" : index + sourceQueue.offset])
            await self.updateQueue(newTrack: track)
        } catch {
            print(error)
        }
    }

    private func updateQueue(newTrack: Track) async {
        print("[QUEUE] smart update")
        if newTrack.id == queueItems.first?.id { // newTrack is the next playing song in the queue
            queueItems = Array(queueItems.dropFirst())
        } else {
            await self.fetchQueueItems()
        }
    }

    func fetchQueueItems() async {
        guard let currentTrack else { print("[QUEUE] Need currentTrack to get current queue"); return }

        print("Fetching current queue")
		do {
			if device.useV2 {
				// v2
				var queueItem = Queue(tracks: [])
				try await queueItem.fetchCurrent(device: device)

				self.sourceQueue = queueItem
				self.queueItems = queueItem.tracks
			} else {
				let data = try await device.sendRequest(endpoint: "playback/queue")
				if let jsonDict = data as? [[String: Any]] {
					// v1
					let attributes: [[String : Any]] = jsonDict.compactMap { $0["attributes"] as? [String : Any] }
					let queue: [Track] = attributes.map { getTrack(using: $0) }

					var queueItem: Queue = .init(tracks: queue)
					queueItem.defineCurrent(track: currentTrack)

					self.sourceQueue = queueItem // after defining offset
					self.queueItems = queueItem.tracks
				}
			}
        } catch {
            print(error)
        }
    }

    private func getTrack(using info: [String: Any]) -> Track {
        // Extract ID from playParams
        var id: String?
        var amId: String?

        if let playParams = info["playParams"] as? [String: Any] {
            id = playParams["id"] as? String
            amId = playParams["catalogId"] as? String
        }

        let title = info["name"] as? String ?? ""
        let artist = info["artistName"] as? String ?? ""
        let album = info["albumName"] as? String ?? ""
        let duration = info["durationInMillis"] as? Double ?? 0

        if let artwork = info["artwork"] as? [String: Any],
           var artworkUrl = artwork["url"] as? String {
            // Replace placeholders in artwork URL
            artworkUrl = artworkUrl.replacingOccurrences(of: "{w}", with: "1024")
            artworkUrl = artworkUrl.replacingOccurrences(of: "{h}", with: "1024")

            let data: Data? = nil

            return Track(id: id ?? "",
                         catalogId: amId ?? "",
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: artworkUrl,
                         duration: duration / 1000,
                         artworkData: data ?? Data()
            )
        } else {
            return Track(id: id ?? "",
                         catalogId: amId ?? "",
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: "",
                         duration: duration / 1000,
                         artworkData: Data()
            )
        }
    }
}
