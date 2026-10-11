import SwiftUI
import AnsiCore

public struct SettingsView: View {
    @ObservedObject var sparkle: SparkleController
    @StateObject private var qlManager = QuickLookManager.shared

    @AppStorage("defaultRows") private var defaultRows: Int = 0
    @AppStorage("defaultFont") private var defaultFont: String = "9x16"
    @AppStorage("SUEnableAutomaticChecks") private var autoCheck: Bool = true
    @AppStorage("SUAutomaticallyUpdate") private var autoDownload: Bool = false

    public init(sparkle: SparkleController) {
        self.sparkle = sparkle
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag("general")

            quickLookTab
                .tabItem {
                    Label("Quick Look", systemImage: "eye")
                }
                .tag("quicklook")

            updatesTab
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag("updates")
        }
        .frame(width: 520, height: 380)
        .padding(20)
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                Picker("Default Screen Rows:", selection: $defaultRows) {
                    Text("Auto (Based on file / SAUCE)").tag(0)
                    Text("25 Rows (Standard BBS)").tag(25)
                    Text("50 Rows (Extended VGA)").tag(50)
                }
                .pickerStyle(.menu)

                Picker("Default Character Font:", selection: $defaultFont) {
                    Text("CP437 9x16 (Authentic IBM VGA 720px)").tag("9x16")
                    Text("CP437 8x16 (Standard ANSI 640px)").tag("8x16")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Default View Preferences")
                    .font(.headline)
            } footer: {
                Text("These settings apply as initial defaults when opening ANSI files. You can always override them for any open file from the View menu.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Quick Look Tab
    private var quickLookTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: qlManager.isEnabled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(qlManager.isEnabled ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(qlManager.isEnabled ? "Finder Quick Look is Active" : "Quick Look Setup Needed")
                        .font(.headline)
                    Text(qlManager.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)

            Text("ANSITime QuickLook allows Finder to instantly preview `.ans`, `.asc`, and `.diz` files with authentic IBM PC CP437 typography when you tap the Spacebar.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 10) {
                Button(action: { qlManager.validate() }) {
                    Label("Validate Setup", systemImage: "arrow.clockwise")
                }
                .disabled(qlManager.isWorking)

                Button(action: { qlManager.fixSetup() }) {
                    Label("Fix / Re-register", systemImage: "wrench.and.screwdriver")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(qlManager.isWorking)

                Button("Open Extension Settings…") {
                    qlManager.openSystemSettings()
                }

                if qlManager.isWorking {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Diagnostic Output:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ScrollView {
                    Text(qlManager.logOutput.isEmpty ? "(Ready)" : qlManager.logOutput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .frame(height: 110)
            }
        }
    }

    // MARK: - Updates Tab
    private var updatesTab: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { val in
                        sparkle.automaticallyChecksForUpdates = val
                    }

                Toggle("Automatically download new updates", isOn: $autoDownload)
                    .onChange(of: autoDownload) { val in
                        sparkle.automaticallyDownloadsUpdates = val
                    }
            } header: {
                Text("Software Updates (Sparkle)")
                    .font(.headline)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Check for Updates") {
                        sparkle.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!sparkle.canCheckForUpdates)
                }
            } footer: {
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("ANSITime Version \(version) (Build \(build))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
