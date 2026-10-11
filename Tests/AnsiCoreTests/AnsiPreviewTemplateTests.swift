import XCTest
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
}
