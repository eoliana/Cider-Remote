// Made by Lumaa

import Foundation

extension UserDefaults {
    static var main: UserDefaults {
        // Force-unwrapping this traps at runtime whenever the App Group
        // entitlement is absent (unsigned builds, or an install where the
        // app group was never provisioned). UserDefaults(suiteName:) returns
        // nil instead of falling back, so the crash happens on first launch,
        // not at build time.
        if let shared = UserDefaults(suiteName: "group.sh.cider.CiderRemote") {
            return shared
        }
        return .standard
    }
}
