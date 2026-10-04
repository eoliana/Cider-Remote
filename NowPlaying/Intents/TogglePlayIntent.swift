// Made by Lumaa

import Foundation
import WidgetKit
import AppIntents

/// Endpoints + response shapes for Cider 4's v2 API.
///
/// The extension was written against v1 (`playback/active`,
/// `playback/is-playing`, `is_playing`) which Cider 4 removed. These match
/// what the main app's own v2 code path uses, so the two cannot drift.
enum CiderAPI {
	/// v1 used `playback/active` as a reachability probe.
	static func reachabilityProbe(for device: DeviceEntity) -> String {
		device.apiVersion == "v2" ? "playback/now-playing" : "playback/active"
	}

	/// v1 `playback/is-playing` -> `{is_playing: 0|1}`;
	/// v2 `playback/state` -> `{state: "playing"|"paused"|...}`.
	static func playingFlag(from data: Any, apiVersion: String) -> Bool {
		guard let json = data as? [String: Any] else { return false }
		if apiVersion == "v2" {
			return (json["state"] as? String) == "playing"
		}
		return (json["is_playing"] as? Int) == 1
	}

	/// v1 read the play state from `playback/is-playing`.
	static func playingStateEndpoint(for device: DeviceEntity) -> String {
		device.apiVersion == "v2" ? "playback/state" : "playback/is-playing"
	}

	static func playPauseEndpoint(apiVersion: String) -> String {
		apiVersion == "v2" ? "playback/toggle" : "playback/playpause"
	}
}

struct TogglePlayIntent: AppIntent, SetValueIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    @Parameter(title: "Action", default: PlaybackEnum.toggle, requestValueDialog: IntentDialog(stringLiteral: "Playback Action"))
    var action: PlaybackEnum

    @Parameter(title: "Device", requestValueDialog: IntentDialog(stringLiteral: "What Cider device do you want to use?"))
    var device: DeviceEntity

    @Parameter(title: "Playing")
    var value: Bool

    init() {}

    init(device: DeviceEntity) {
        self.device = device
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) the current track on \(\.$device)")
    }

    func perform() async throws -> some IntentResult {
        let (statusCode, _) = await device.sendRequest(endpoint: CiderAPI.reachabilityProbe(for: device))

        if statusCode == 200 {
            (_, _) = await device.sendRequest(endpoint: self.action.endpoint(apiVersion: device.apiVersion), method: "POST")

            let (_, data) = await device.sendRequest(endpoint: CiderAPI.playingStateEndpoint(for: device), method: "GET")
            if let jsonDict = data as? [String: Any] {
                self.device.isPlaying = CiderAPI.playingFlag(from: jsonDict, apiVersion: device.apiVersion)

                if #available(iOS 18.0, *) {
                    ControlCenter.shared.reloadControls(ofKind: "sh.cider.CiderRemote.PlayPauseControl")
                }
            }
            return .result()
        } else {
            self.device.isPlaying = false
            print("[AppIntent] - No toggle \(statusCode)")
        }
        return .result()
    }
}

/// This is the exact same as ``TogglePlayIntent`` but used in the ``NowPlayingLiveActivity``
struct TogglePlayButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    static var isDiscoverable: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle play/pause on Cider")
    }

    var device: DeviceEntity?

    func perform() async throws -> some IntentResult {
        guard let devices = await self.getDevices() else { return .result() }

        for device in devices {
            let (statusCode, _) = await device.sendRequest(endpoint: CiderAPI.reachabilityProbe(for: device))

            if statusCode == 200 {
                (_, _) = await device.sendRequest(endpoint: CiderAPI.playPauseEndpoint(apiVersion: device.apiVersion), method: "POST")

                if #available(iOS 18.0, *) {
                    ControlCenter.shared.reloadControls(ofKind: "sh.cider.CiderRemote.PlayPauseControl")
                }

                return .result()
            } else {
                print("[AppIntent] - No toggle \(statusCode)")
            }
        }

        return .result()
    }

    private func getDevices() async -> [DeviceEntity]? {
        if let device {
            return [device]
        } else {
            return try? await DeviceQuery().suggestedEntities()
        }
    }
}
