// Made by Lumaa

import WidgetKit
import SwiftUI

@main
struct NowPlayingBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 18.0, *) {
            return Bundle18
        } else {
            return BundleOld
        }
    }
}

@available(iOS 18.0, *)
@WidgetBundleBuilder
private var Bundle18: some Widget {
    NowPlayingLiveActivity()

    // Home-screen widget: art + controls + lyric line.
    CiderNowPlayingWidget()

    // control center
    PlayPauseControl()
    TimeTrackControl()
}

@WidgetBundleBuilder
private var BundleOld: some Widget {
    NowPlayingLiveActivity()

    CiderNowPlayingWidget()
}
