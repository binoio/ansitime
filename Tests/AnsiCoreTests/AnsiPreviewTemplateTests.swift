import XCTest
#if canImport(WebKit)
import WebKit
#endif
@testable import AnsiCore

final class AnsiPreviewTemplateTests: XCTestCase {
    func testRenderHTMLGeneratesValidStructure() {
        let raw = Data("\u{1b}[32mGreen ANSI Text\u{1b}[0m".utf8)
        let doc = AnsiDocument(data: raw)

        let html = AnsiPreviewTemplate.renderHTML(document: doc, rows: 25, fontChoice: .cp437_9x16, showHud: true)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<div id=\"fTelnetContainer\"></div>"))
        XCTAssertTrue(html.contains("options.ScreenRows = 25;"))
        XCTAssertTrue(html.contains("options.ScreenColumns = 80;"))
        XCTAssertTrue(html.contains("options.SplashScreen = '\(doc.ftelnetPayloadBase64)';"))
        XCTAssertTrue(html.contains("FONT_9x16"))
        XCTAssertTrue(html.contains("FONT_8x16"))
    }

    func testRenderHTMLSupports8x16Font() {
        let raw = Data("\u{1b}[33mYellow ANSI\u{1b}[0m".utf8)
        let doc = AnsiDocument(data: raw)

        let html = AnsiPreviewTemplate.renderHTML(document: doc, rows: 50, fontChoice: .cp437_8x16, showHud: false)

        XCTAssertTrue(html.contains("options.ScreenRows = 50;"))
        XCTAssertTrue(html.contains("options.ScreenColumns = 80;"))
        XCTAssertTrue(html.contains("var TARGET_FONT_NAME = 'CP437_8x16';"))
        XCTAssertTrue(html.contains("var TARGET_WIDTH = 8;"))
    }

    func testRenderHTMLAutoRowsDefaultsToDocRecommendation() {
        let raw = Data("\u{1b}[36mCyan ANSI\u{1b}[0m".utf8)
        let doc = AnsiDocument(data: raw)

        let html = AnsiPreviewTemplate.renderHTML(document: doc, rows: nil, fontChoice: .cp437_9x16, showHud: false)

        XCTAssertTrue(html.contains("options.ScreenRows = \(doc.recommendedRows);"))
        XCTAssertTrue(html.contains("var TARGET_FONT_NAME = 'CP437_9x16';"))
        XCTAssertTrue(html.contains("var TARGET_WIDTH = 9;"))
    }
#if canImport(WebKit)
    func testWKWebViewRendering() throws {
        let url = URL(fileURLWithPath: "logon-scene.ans")
        let doc = try AnsiDocument(contentsOf: url)
        let html = AnsiPreviewTemplate.renderHTML(document: doc, rows: nil, fontChoice: .cp437_9x16, showHud: false)

        let exp = expectation(description: "WKWebView loaded")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        webView.loadHTMLString(html, baseURL: nil)

        class Helper: NSObject, WKNavigationDelegate {
            var onFinish: (() -> Void)?
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                onFinish?()
            }
        }
        let helper = Helper()
        helper.onFinish = {
            webView.evaluateJavaScript("""
                (function() {
                    var c = window.client;
                    var crt = c ? c._Crt : null;
                    return JSON.stringify({
                        hasClient: !!c,
                        hasCrt: !!crt,
                        allowDynamic: crt ? crt._AllowDynamicFontResize : null,
                        fontName: crt ? crt._Font.Name : null,
                        fontSize: crt ? [crt._Font.Size.x, crt._Font.Size.y] : null,
                        canvasSize: crt ? [crt._Canvas.width, crt._Canvas.height] : null
                    });
                })()
            """) { res, err in
                print("--- INITIAL STATE ---:", res as Any, "ERR:", err as Any)

                // Now simulate window resize down to narrow frame
                webView.evaluateJavaScript("""
                    (function() {
                        window.innerWidth = 400;
                        window.innerHeight = 300;
                        window.dispatchEvent(new Event('resize'));
                        var c = window.client;
                        var crt = c ? c._Crt : null;
                        var sb = document.querySelector('.fTelnetStatusBar');
                        return JSON.stringify({
                            allowDynamic: crt ? crt._AllowDynamicFontResize : null,
                            fontName: crt ? crt._Font.Name : null,
                            fontSize: crt ? [crt._Font.Size.x, crt._Font.Size.y] : null,
                            canvasSize: crt ? [crt._Canvas.width, crt._Canvas.height] : null,
                            statusBarVisible: sb ? (getComputedStyle(sb).display !== 'none') : false
                        });
                    })()
                """) { res2, err2 in
                    if let jsonStr = res2 as? String,
                       let data = jsonStr.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let fontSize = obj["fontSize"] as? [Int]
                        XCTAssertEqual(fontSize, [9, 16])
                        XCTAssertEqual(obj["statusBarVisible"] as? Bool, false)
                    } else {
                        XCTFail("Failed to parse resize response")
                    }
                    exp.fulfill()
                }
            }
        }
        webView.navigationDelegate = helper

        wait(for: [exp], timeout: 10.0)
    }
#endif
}
