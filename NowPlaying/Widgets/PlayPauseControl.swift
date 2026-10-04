// Made by Lumaa

import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 18.0, *)
struct PlayPauseControl: ControlWidget {
    static let kind: String = "sh.cider.CiderRemote.PlayPauseControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Self.Provider()) { device in
            ControlWidgetToggle(
                device.name,
                isOn: device.isPlaying,
                action: TogglePlayIntent(device: device),
                valueLabel: { isPlaying in
                    Label(isPlaying ? "Playing" : "Paused", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .controlWidgetActionHint(isPlaying ? "Play track" : "Pause track")
                }
            )
            .tint(Color.cider)
            .disabled(!device.isActive)
        }
        .displayName("Play/Pause a device")
        .description("Play or pause any selected Cider device")
        .promptsForUserConfiguration()
    }

    struct PlayPauseConfiguration: ControlConfigurationIntent {
        static var title: LocalizedStringResource = "Select a Device"
        static var description: IntentDescription?  = IntentDescription(stringLiteral: "Select the Cider instance to use the play/pause action.")

        @Parameter(title: "Device")
        var device: DeviceEntity?

        init(device: DeviceEntity) {
            self.device = device
        }

        init() {}
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: PlayPauseControl.PlayPauseConfiguration) -> DeviceEntity {
            var device: DeviceEntity = configuration.device ?? .placeholder
            device.isPlaying = false

            return device
        }

        func currentValue(configuration: PlayPauseControl.PlayPauseConfiguration) async throws -> DeviceEntity {
            return try await self.fetchPlaying(configuration)
        }

        private func fetchPlaying(_ configuration: PlayPauseControl.PlayPauseConfiguration) async throws -> DeviceEntity {
            guard var device = configuration.device else { return .placeholder }

            let (status, data) = await device.sendRequest(endpoint: CiderAPI.playingStateEndpoint(for: device), method: "GET")
            if status == 200 {
                if let jsonDict = data as? [String: Any] {
                    let j = CiderAPI.playingFlag(from: jsonDict, apiVersion: device.apiVersion)
                    print(j ? "[Control] - playing" : "[Control - paused]")
                    device.isActive = true
                    device.isPlaying = j

                    return device
                } else {
                    device.isActive = true
                    device.isPlaying = false
                    return device
                }
            } else {
                device.isActive = false
                device.isPlaying = false
                return device
            }
        }
    }
}

extension DeviceEntity {
    static let placeholder: DeviceEntity = .init(name: "Cider Device", token: "ABC", host: "ABC", isPlaying: false)
}
