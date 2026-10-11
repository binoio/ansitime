import SwiftUI
import AppKit
import WebKit
import AnsiCore

public struct ExportModalView: View {
    let document: AnsiDocument?
    let fileURL: URL?
    let webView: WKWebView?
    @Binding var isPresented: Bool

    @State private var copiedConfirmation = false

    public init(
        document: AnsiDocument?,
        fileURL: URL?,
        webView: WKWebView?,
        isPresented: Binding<Bool>
    ) {
        self.document = document
        self.fileURL = fileURL
        self.webView = webView
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Export & Share")
                        .font(.headline)
                    Text(fileURL?.lastPathComponent ?? "ANSI Document")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // Export Actions
            VStack(spacing: 12) {
                // Option 1: Export as PNG
                Button(action: exportAsPNG) {
                    HStack(spacing: 14) {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export as PNG…")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Render full ANSI canvas to a lossless PNG image file.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(document == nil || webView == nil)

                // Option 2: Copy Plain Text
                Button(action: copyPlainText) {
                    HStack(spacing: 14) {
                        Image(systemName: copiedConfirmation ? "checkmark.circle.fill" : "doc.on.clipboard")
                            .font(.system(size: 20))
                            .foregroundColor(copiedConfirmation ? .green : .orange)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(copiedConfirmation ? "Copied to Clipboard!" : "Copy Plain Text")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Strip ANSI escape codes and copy text to pasteboard.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if copiedConfirmation {
                            Text("Copied")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(document == nil)

                // Option 3: Standard macOS Share Sheet
                Button(action: shareViaMacOS) {
                    HStack(spacing: 14) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share via macOS…")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Send via AirDrop, Mail, Messages, or Notes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(document == nil)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func exportAsPNG() {
        guard let webView = webView else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        let baseName = fileURL?.deletingPathExtension().lastPathComponent ?? "ansi-render"
        savePanel.nameFieldStringValue = "\(baseName).png"

        isPresented = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if savePanel.runModal() == .OK, let targetURL = savePanel.url {
                let config = WKSnapshotConfiguration()
                webView.takeSnapshot(with: config) { image, _ in
                    guard let image = image,
                          let tiff = image.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else {
                        return
                    }
                    try? png.write(to: targetURL)
                }
            }
        }
    }

    private func copyPlainText() {
        guard let doc = document else { return }
        if let text = String(data: doc.sanitizedAnsiData, encoding: .isoLatin1) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation {
                copiedConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    copiedConfirmation = false
                }
            }
        }
    }

    private func shareViaMacOS() {
        guard let doc = document else { return }
        isPresented = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var items: [Any] = []
            if let url = fileURL {
                items.append(url)
            }
            if let text = String(data: doc.sanitizedAnsiData, encoding: .isoLatin1) {
                items.append(text)
            }

            guard !items.isEmpty else { return }
            let picker = NSSharingServicePicker(items: items)
            if let window = NSApplication.shared.keyWindow, let view = window.contentView {
                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            }
        }
    }
}
