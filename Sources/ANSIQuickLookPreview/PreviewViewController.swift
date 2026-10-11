import Cocoa
import QuickLookUI
import WebKit
import AnsiCore

@objc(PreviewViewController)
public class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private var webView: WKWebView!

    public override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.autoresizingMask = [.width, .height]

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground") // Transparent background

        view.addSubview(webView)
        self.view = view
    }

    public func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let document = try AnsiDocument(contentsOf: url)

            // Calculate ideal window size
            let width = max(760, (document.recommendedCols * 9) + 40)
            let height = max(480, (document.recommendedRows * 16) + 90)
            self.preferredContentSize = NSSize(width: width, height: height)

            let html = AnsiPreviewTemplate.renderHTML(
                document: document,
                rows: document.recommendedRows,
                fontChoice: .cp437_9x16,
                showHud: true
            )

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.webView.loadHTMLString(html, baseURL: nil)
                handler(nil)
            }
        } catch {
            handler(error)
        }
    }
}
