// Made for the sideloaded Cider Remote build

import AppIntents
import WidgetKit

/// Transport intents for the home-screen widget. Thin wrappers over the same
/// `CiderAPI` endpoint mapping the Live Activity uses, so the widget and the
/// activity cannot drift apart on Cider 4.
struct WidgetPlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Device") var device: DeviceEntity?

    init() {}

    init(device: DeviceEntity) { self.device = device }

    func perform() async throws -> some IntentResult {
        guard let device else { return .result() }
        let (_, _) = await device.sendRequest(endpoint: CiderAPI.playPauseEndpoint(apiVersion: device.apiVersion), method: "POST")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WidgetRewindIntent: AppIntent {
    static var title: LocalizedStringResource = "Rewind"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Device") var device: DeviceEntity?

    init() {}

    init(device: DeviceEntity) { self.device = device }

    func perform() async throws -> some IntentResult {
        guard let device else { return .result() }
        // Cider has no "restart current track" endpoint distinct from a seek,
        // so the widget's rewind goes to the previous track outright (unlike
        // the in-app button, which rewinds within the track first).
        let (_, _) = await device.sendRequest(endpoint: "playback/previous", method: "POST")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WidgetSkipIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Device") var device: DeviceEntity?

    init() {}

    init(device: DeviceEntity) { self.device = device }

    func perform() async throws -> some IntentResult {
        guard let device else { return .result() }
        let (_, _) = await device.sendRequest(endpoint: "playback/next", method: "POST")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}