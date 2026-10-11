import SwiftUI
import WebKit
import UniformTypeIdentifiers
import AnsiCore

public struct ContentView: View {
    @State private var currentDocument: AnsiDocument?
    @State private var currentURL: URL?
    @State private var selectedRows: Int? = nil // nil = Auto
    @State private var selectedFont: AnsiPreviewTemplate.FontChoice = .cp437_9x16
    @State private var showInspector = false
    @State private var showQuickLookStatus = false
    @State private var webViewRef: WKWebView?
    @State private var isTargetedForDrop = false
    @ObservedObject var sparkle: SparkleController

    public init(sparkle: SparkleController) {
        self.sparkle = sparkle
    }

    public var body: some View {
        NavigationSplitView {
            // Main content area
            ZStack {
                Color(NSColor.black)
                    .ignoresSafeArea()

                if let doc = currentDocument {
                    ViewerWebView(
                        htmlString: AnsiPreviewTemplate.renderHTML(
                            document: doc,
                            rows: selectedRows ?? doc.recommendedRows,
                            fontChoice: selectedFont,
                            showHud: false
                        ),
                        webViewRef: $webViewRef
                    )
                } else {
                    emptyStateView
                }

                if isTargetedForDrop {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                        .background(Color.green.opacity(0.1))
                        .padding(16)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                handleDrop(providers: providers)
            }
        } detail: {
            if showInspector {
                SauceInspectorView(sauce: currentDocument?.sauce)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: openFile) {
                    Label("Open", systemImage: "folder")
                }
                .help("Open ANSI Art file (.ans, .asc)")
            }

            ToolbarItemGroup(placement: .principal) {
                Picker("Rows", selection: $selectedRows) {
                    Text("Auto").tag(Int?.none)
                    Text("25 Rows").tag(Int?.some(25))
                    Text("50 Rows").tag(Int?.some(50))
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Picker("Font", selection: $selectedFont) {
                    Text("CP437 9x16").tag(AnsiPreviewTemplate.FontChoice.cp437_9x16)
                    Text("CP437 8x16").tag(AnsiPreviewTemplate.FontChoice.cp437_8x16)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Export as PNG...", action: exportAsPNG)
                        .disabled(currentDocument == nil)
                    Button("Copy Plain Text", action: copyPlainText)
                        .disabled(currentDocument == nil)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button(action: { showInspector.toggle() }) {
                    Label("SAUCE Inspector", systemImage: "info.circle")
                }
                .help("Toggle SAUCE Metadata Inspector")

                Button(action: { showQuickLookStatus.toggle() }) {
                    Label("Quick Look Status", systemImage: "eye")
                }
                .help("Quick Look Extension Status & Guide")
            }
        }
        .sheet(isPresented: $showQuickLookStatus) {
            quickLookStatusSheet
        }
        .onAppear {
            loadDefaultSampleIfAvailable()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.green.opacity(0.8))

            Text("ANSI QuickLook")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Drag & drop any .ans or .asc file here,\nor click Open to preview BBS art.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)

            Button("Open File...", action: openFile)
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(40)
    }

    private var quickLookStatusSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Finder Quick Look Extension")
                    .font(.headline)
                Spacer()
                Button("Done") { showQuickLookStatus = false }
            }

            Text("ANSI QuickLook includes a Finder Quick Look plugin for spacebar previews of .ans, .asc, and .diz files.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("How to Test Finder Preview:")
                    .fontWeight(.semibold)
                Text("1. In Finder, highlight any `.ans` file.")
                Text("2. Press the **Spacebar**.")
                Text("3. Quick Look will instantly render the authentic fTelnet BBS splash screen.")
            }
            .font(.caption)

            VStack(alignment: .leading, spacing: 6) {
                Text("If Quick Look is disabled in macOS:")
                    .fontWeight(.semibold)
                Text("Go to **System Settings > Privacy & Security > Extensions > Quick Look** and ensure **ANSI QuickLook** is checked.")
                Text("Or run in Terminal: `qlmanage -r && qlmanage -r cache`")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            Spacer()
        }
        .padding(24)
        .frame(width: 480, height: 320)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "ans") ?? .plainText,
            UTType(filenameExtension: "asc") ?? .plainText,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }

    private func loadFile(url: URL) {
        do {
            let doc = try AnsiDocument(contentsOf: url)
            self.currentDocument = doc
            self.currentURL = url
            self.selectedRows = nil // Reset to Auto
        } catch {
            print("Error loading ANSI file: \(error)")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    self.loadFile(url: url)
                }
            } else if let url = item as? URL {
                DispatchQueue.main.async {
                    self.loadFile(url: url)
                }
            }
        }
        return true
    }

    private func exportAsPNG() {
        guard let webView = webViewRef else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        let baseName = currentURL?.deletingPathExtension().lastPathComponent ?? "ansi-render"
        savePanel.nameFieldStringValue = "\(baseName).png"

        if savePanel.runModal() == .OK, let targetURL = savePanel.url {
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, error in
                guard let image = image, let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    return
                }
                try? png.write(to: targetURL)
            }
        }
    }

    private func copyPlainText() {
        guard let doc = currentDocument else { return }
        if let text = String(data: doc.sanitizedAnsiData, encoding: .isoLatin1) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    private func loadDefaultSampleIfAvailable() {
        // Automatically load bean-board-wide.ans or splash.ans if present in current directory
        let wideUrl = URL(fileURLWithPath: "bean-board-wide.ans")
        if FileManager.default.fileExists(atPath: wideUrl.path) {
            loadFile(url: wideUrl)
        }
    }
}
