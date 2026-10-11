import Foundation
import AppKit

public final class QuickLookManager: ObservableObject {
    @Published public var isRegistered: Bool = false
    @Published public var isEnabled: Bool = false
    @Published public var statusMessage: String = "Checking Quick Look status…"
    @Published public var logOutput: String = ""
    @Published public var isWorking: Bool = false

    public static let shared = QuickLookManager()

    public init() {
        validate()
    }

    public func validate() {
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.runShell("pluginkit -m -v -i io.bino.ansitime.quicklook")
            DispatchQueue.main.async {
                self.logOutput = output.isEmpty ? "(No pluginkit response)" : output
                self.isWorking = false
                if output.contains("io.bino.ansitime.quicklook") {
                    self.isRegistered = true
                    if output.contains("+") {
                        self.isEnabled = true
                        self.statusMessage = "ANSITime QuickLook is enabled and active in Finder."
                    } else {
                        self.isEnabled = false
                        self.statusMessage = "ANSITime QuickLook is registered but disabled in System Settings."
                    }
                } else {
                    self.isRegistered = false
                    self.isEnabled = false
                    self.statusMessage = "ANSITime QuickLook is not currently registered with macOS."
                }
            }
        }
    }

    public func fixSetup() {
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async {
            var combined = "=== Quick Look Setup & Repair ===\n\n"

            // 1. Locate extension appex
            var appexPath: String? = nil
            if let pluginsURL = Bundle.main.builtInPlugInsURL {
                let candidate = pluginsURL.appendingPathComponent("ANSITimeQuickLook.appex").path
                if FileManager.default.fileExists(atPath: candidate) {
                    appexPath = candidate
                }
            }
            if appexPath == nil {
                let systemPath = "/Applications/ANSITime.app/Contents/PlugIns/ANSITimeQuickLook.appex"
                if FileManager.default.fileExists(atPath: systemPath) {
                    appexPath = systemPath
                }
            }

            if let path = appexPath {
                combined += "Found extension at: \(path)\n"
                let addResult = self.runShell("pluginkit -a \"\(path)\"")
                combined += "1. pluginkit add: \(addResult.isEmpty ? "OK" : addResult)\n"
            } else {
                combined += "Notice: Standalone bundle not installed to /Applications yet.\n"
            }

            let enableResult = self.runShell("pluginkit -e use -i io.bino.ansitime.quicklook")
            combined += "2. pluginkit enable: \(enableResult.isEmpty ? "OK" : enableResult)\n"

            let qlmanageReset = self.runShell("qlmanage -r")
            combined += "3. qlmanage -r: \(qlmanageReset.trimmingCharacters(in: .whitespacesAndNewlines))\n"

            let qlmanageCache = self.runShell("qlmanage -r cache")
            combined += "4. qlmanage -r cache: \(qlmanageCache.trimmingCharacters(in: .whitespacesAndNewlines))\n"

            let verify = self.runShell("pluginkit -m -v -i io.bino.ansitime.quicklook")
            combined += "\n=== Verification ===\n\(verify)\n"

            DispatchQueue.main.async {
                self.logOutput = combined
                self.isWorking = false
                if verify.contains("io.bino.ansitime.quicklook") {
                    self.isRegistered = true
                    self.isEnabled = verify.contains("+")
                    self.statusMessage = self.isEnabled
                        ? "ANSITime QuickLook is successfully registered and active!"
                        : "ANSITime QuickLook registered, but disabled in System Settings."
                } else {
                    self.isRegistered = false
                    self.isEnabled = false
                    self.statusMessage = "Could not register extension. Try moving ANSITime to /Applications."
                }
            }
        }
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    private func runShell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
