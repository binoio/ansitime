import SwiftUI
import WebKit
import AnsiCore

public struct ViewerWebView: NSViewRepresentable {
    public let htmlString: String
    @Binding public var webViewRef: WKWebView?

    public init(htmlString: String, webViewRef: Binding<WKWebView?> = .constant(nil)) {
        self.htmlString = htmlString
        self._webViewRef = webViewRef
    }

    public class Coordinator {
        var lastHTML: String?
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        DispatchQueue.main.async {
            self.webViewRef = webView
        }
        context.coordinator.lastHTML = htmlString
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        // Prevent redundant reloads during SwiftUI layout passes (e.g. sidebar toggle or resize animation)
        if context.coordinator.lastHTML != htmlString {
            context.coordinator.lastHTML = htmlString
            nsView.loadHTMLString(htmlString, baseURL: nil)
        }
    }
}
