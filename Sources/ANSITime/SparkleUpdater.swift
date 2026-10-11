import SwiftUI
#if canImport(Sparkle)
import Sparkle

public final class SparkleController: ObservableObject {
    @Published public var canCheckForUpdates: Bool = false
    private var updaterController: SPUStandardUpdaterController?

    public init() {
        if Bundle.main.bundleIdentifier != nil {
            let controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            self.updaterController = controller
            self.canCheckForUpdates = controller.updater.canCheckForUpdates
        }
    }

    public func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    public var automaticallyChecksForUpdates: Bool {
        get {
            updaterController?.updater.automaticallyChecksForUpdates ??
            UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks")
        }
        set {
            updaterController?.updater.automaticallyChecksForUpdates = newValue
            UserDefaults.standard.set(newValue, forKey: "SUEnableAutomaticChecks")
        }
    }

    public var automaticallyDownloadsUpdates: Bool {
        get {
            updaterController?.updater.automaticallyDownloadsUpdates ??
            UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate")
        }
        set {
            updaterController?.updater.automaticallyDownloadsUpdates = newValue
            UserDefaults.standard.set(newValue, forKey: "SUAutomaticallyUpdate")
        }
    }
}
#else
public final class SparkleController: ObservableObject {
    public init() {}

    public func checkForUpdates() {
        if let url = URL(string: "https://bino.io/ansitime") {
            NSWorkspace.shared.open(url)
        }
    }

    public var canCheckForUpdates: Bool { true }

    public var automaticallyChecksForUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") }
        set { UserDefaults.standard.set(newValue, forKey: "SUEnableAutomaticChecks") }
    }

    public var automaticallyDownloadsUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate") }
        set { UserDefaults.standard.set(newValue, forKey: "SUAutomaticallyUpdate") }
    }
}
#endif
