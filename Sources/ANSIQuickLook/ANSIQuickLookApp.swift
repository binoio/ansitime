import SwiftUI
import AppKit

@main
struct ANSIQuickLookApp: App {
    @StateObject private var sparkle = SparkleController()

    var body: some Scene {
        WindowGroup {
            ContentView(sparkle: sparkle)
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
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
