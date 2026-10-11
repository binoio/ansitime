import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenFile: ((URL) -> Void)?

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        onOpenFile?(url)
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if let first = filenames.first {
            let url = URL(fileURLWithPath: first)
            onOpenFile?(url)
        }
        sender.reply(toOpenOrPrint: .success)
    }
}

public final class AppModel: ObservableObject {
    @Published public var requestedURL: URL?

    public init() {}

    public func open(url: URL) {
        self.requestedURL = url
    }
}

@main
struct ANSIQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sparkle = SparkleController()
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(sparkle: sparkle, appModel: appModel)
                .frame(minWidth: 900, minHeight: 650)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    appModel.open(url: url)
                }
                .onAppear {
                    appDelegate.onOpenFile = { url in
                        DispatchQueue.main.async {
                            appModel.open(url: url)
                        }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    sparkle.checkForUpdates()
                }
                .disabled(!sparkle.canCheckForUpdates)
            }

            CommandGroup(replacing: .help) {
                Button("ANSI QuickLook on bino.io") {
                    if let url = URL(string: "https://bino.io") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("GitHub Repository (binoio/ansi-quicklook)") {
                    if let url = URL(string: "https://github.com/binoio/ansi-quicklook") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
