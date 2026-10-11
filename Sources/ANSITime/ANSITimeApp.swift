import SwiftUI
import AppKit
import AnsiCore

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
    @Published public var triggerOpenFile: Bool = false
    @Published public var selectedRows: Int? = nil // nil = Auto
    @Published public var selectedFont: AnsiPreviewTemplate.FontChoice = .cp437_9x16
    @Published public var showInspector: Bool = false
    @Published public var showExportModal: Bool = false
    @Published public var autoRowsSummary: String = "25"

    public init() {
        let storedFont = UserDefaults.standard.string(forKey: "defaultFont") ?? "9x16"
        self.selectedFont = (storedFont == "8x16") ? .cp437_8x16 : .cp437_9x16

        let storedRows = UserDefaults.standard.integer(forKey: "defaultRows")
        if storedRows > 0 {
            self.selectedRows = storedRows
        }
    }

    public func open(url: URL) {
        self.requestedURL = url
    }

    public func requestOpenFile() {
        self.triggerOpenFile = true
    }
}

@main
struct ANSITimeApp: App {
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
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    appModel.requestOpenFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Export & Share…") {
                    appModel.showExportModal = true
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // View Menu
            CommandMenu("View") {
                Menu("Screen Rows") {
                    Button(appModel.selectedRows == nil ? "✓ Auto (\(appModel.autoRowsSummary))" : "  Auto (\(appModel.autoRowsSummary))") {
                        appModel.selectedRows = nil
                    }
                    Divider()
                    Button(appModel.selectedRows == 25 ? "✓ 25 Rows (Standard BBS)" : "  25 Rows (Standard BBS)") {
                        appModel.selectedRows = 25
                    }
                    Button(appModel.selectedRows == 50 ? "✓ 50 Rows (Extended VGA)" : "  50 Rows (Extended VGA)") {
                        appModel.selectedRows = 50
                    }
                }

                Menu("Character Font") {
                    Button(appModel.selectedFont == .cp437_9x16 ? "✓ CP437 9x16 (Authentic IBM VGA)" : "  CP437 9x16 (Authentic IBM VGA)") {
                        appModel.selectedFont = .cp437_9x16
                    }
                    Button(appModel.selectedFont == .cp437_8x16 ? "✓ CP437 8x16 (Standard ANSI)" : "  CP437 8x16 (Standard ANSI)") {
                        appModel.selectedFont = .cp437_8x16
                    }
                }

                Divider()

                Button(appModel.showInspector ? "Hide SAUCE Inspector" : "Show SAUCE Inspector") {
                    appModel.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }

            // Application Menu
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    sparkle.checkForUpdates()
                }
                .disabled(!sparkle.canCheckForUpdates)
            }

            // Help Menu
            CommandGroup(replacing: .help) {
                Button("ANSITime on bino.io") {
                    if let url = URL(string: "https://bino.io/ansitime") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("GitHub Repository (binoio/ansitime)") {
                    if let url = URL(string: "https://github.com/binoio/ansitime") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        // Settings Window (⌘,)
        Settings {
            SettingsView(sparkle: sparkle)
        }
    }
}
