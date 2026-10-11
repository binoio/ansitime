import SwiftUI
import WebKit
import UniformTypeIdentifiers
import AnsiCore

public struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var nearbyFiles: [URL] = []
    @State private var selectedURL: URL? = nil
    @State private var currentDocument: AnsiDocument? = nil
    @State private var webViewRef: WKWebView?
    @State private var isTargetedForDrop = false

    @AppStorage("defaultRows") private var defaultRows: Int = 0
    @AppStorage("defaultFont") private var defaultFont: String = "9x16"

    @ObservedObject var sparkle: SparkleController
    @ObservedObject var appModel: AppModel

    public init(sparkle: SparkleController, appModel: AppModel) {
        self.sparkle = sparkle
        self.appModel = appModel
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR: List of ANSI files in directory (collapsed by default)
            List(nearbyFiles, id: \.self, selection: $selectedURL) { fileURL in
                HStack(spacing: 10) {
                    Image(systemName: "terminal")
                        .foregroundColor(.green)
                    Text(fileURL.lastPathComponent)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 4)
                .tag(fileURL)
            }
            .navigationTitle("Files")
            .listStyle(.sidebar)
        } detail: {
            // DETAIL: Centered ANSI canvas
            ZStack {
                Color(red: 0.05, green: 0.04, blue: 0.03)
                    .ignoresSafeArea()

                if let doc = currentDocument {
                    ViewerWebView(
                        htmlString: AnsiPreviewTemplate.renderHTML(
                            document: doc,
                            rows: activeRows(for: doc),
                            fontChoice: appModel.selectedFont,
                            showHud: false
                        ),
                        webViewRef: $webViewRef
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyStateView
                }

                if isTargetedForDrop {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                        .background(Color.green.opacity(0.15))
                        .padding(24)
                }
            }
            .navigationTitle(selectedURL?.lastPathComponent ?? "ANSITime")
            .inspector(isPresented: $appModel.showInspector) {
                SauceInspectorView(sauce: currentDocument?.sauce)
                    .inspectorColumnWidth(min: 240, ideal: 280, max: 320)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { appModel.showExportModal = true }) {
                    Label("Export & Share", systemImage: "square.and.arrow.up")
                }
                .help("Export PNG, copy text, or share via macOS (⇧⌘E)")
                .disabled(currentDocument == nil)

                Button(action: { appModel.showInspector.toggle() }) {
                    Label("SAUCE Inspector", systemImage: "info.circle")
                }
                .help("Toggle SAUCE Metadata Inspector (⌥⌘I)")
            }
        }
        .sheet(isPresented: $appModel.showExportModal) {
            ExportModalView(
                document: currentDocument,
                fileURL: selectedURL,
                webView: webViewRef,
                isPresented: $appModel.showExportModal
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: selectedURL) { newURL in
            if let url = newURL {
                loadFile(url: url)
            }
        }
        .onChange(of: appModel.requestedURL) { newURL in
            if let url = newURL {
                scanDirectory(containing: url)
                selectedURL = url
                loadFile(url: url)
            }
        }
        .onChange(of: appModel.triggerOpenFile) { trigger in
            if trigger {
                appModel.triggerOpenFile = false
                openFile()
            }
        }
        .onChange(of: defaultFont) { newFont in
            appModel.selectedFont = (newFont == "8x16") ? .cp437_8x16 : .cp437_9x16
        }
        .onAppear {
            if let url = appModel.requestedURL {
                scanDirectory(containing: url)
                selectedURL = url
                loadFile(url: url)
            } else {
                scanDirectoryAndLoadInitial()
            }
        }
    }

    private func activeRows(for doc: AnsiDocument) -> Int {
        if let userRow = appModel.selectedRows {
            return userRow
        }
        if defaultRows > 0 {
            return defaultRows
        }
        return doc.recommendedRows
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.green.opacity(0.8))

            Text("ANSITime")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Drag & drop any .ans or .asc file here,\nor choose File > Open (⌘O).")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)

            Button("Open File...", action: openFile)
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(40)
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
            scanDirectory(containing: url)
            selectedURL = url
            loadFile(url: url)
        }
    }

    private func scanDirectoryAndLoadInitial() {
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        scanDirectory(containing: currentDir)

        if let first = nearbyFiles.first {
            selectedURL = first
            loadFile(url: first)
        }
    }

    private func scanDirectory(containing fileOrDir: URL) {
        let dir = fileOrDir.hasDirectoryPath ? fileOrDir : fileOrDir.deletingLastPathComponent()
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }

        let supported = ["ans", "asc", "diz"]
        let ansFiles = items.filter { supported.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if !ansFiles.isEmpty {
            self.nearbyFiles = ansFiles
        }
    }

    private func loadFile(url: URL) {
        do {
            let doc = try AnsiDocument(contentsOf: url)
            self.currentDocument = doc
            self.appModel.autoRowsSummary = "\(doc.recommendedRows)"
        } catch {
            print("Error loading ANSI file: \(error)")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var targetURL: URL? = nil
            if let data = item as? Data {
                targetURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                targetURL = url
            }

            if let url = targetURL {
                DispatchQueue.main.async {
                    self.scanDirectory(containing: url)
                    self.selectedURL = url
                    self.loadFile(url: url)
                }
            }
        }
        return true
    }
}
