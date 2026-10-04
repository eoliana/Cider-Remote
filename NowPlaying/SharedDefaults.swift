// Made for the sideloaded Cider Remote build

import Foundation

extension UserDefaults {
    /// Shared storage between the app and the widget extension.
    ///
    /// This lives in the extension's own target rather than relying on the
    /// app's copy being compiled into it. When the App Group entitlement is
    /// absent (unsigned install, or a signer that never provisioned
    /// `group.sh.cider.CiderRemote`) `suiteName` returns nil, so this falls
    /// back to .standard rather than trapping.
    static var main: UserDefaults {
        if let shared = UserDefaults(suiteName: "group.sh.cider.CiderRemote") {
            return shared
        }
        return .standard
    }
}