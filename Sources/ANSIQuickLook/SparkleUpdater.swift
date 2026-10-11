import SwiftUI
#if canImport(Sparkle)
import Sparkle

public final class SparkleController: ObservableObject {
    private var updaterController: SPUStandardUpdaterController?

    public init() {
        // Only initialize if bundle identifier and Info.plist are present
        if Bundle.main.bundleIdentifier != nil {
            self.updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }

    public func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    public var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }
}
#else
public final class SparkleController: ObservableObject {
    public init() {}

    public func checkForUpdates() {
        if let url = URL(string: "https://bino.io/ansi-quicklook") {
            NSWorkspace.shared.open(url)
        }
    }

    public var canCheckForUpdates: Bool { true }
}
#endif
