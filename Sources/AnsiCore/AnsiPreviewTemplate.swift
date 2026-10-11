import Foundation

public struct AnsiPreviewTemplate: Sendable {
    public enum FontChoice: String, CaseIterable, Sendable {
        case cp437_9x16 = "CP437 (9x16)"
        case cp437_8x16 = "CP437 (8x16)"

        public var fontName: String { "CP437" }
        public var width: Int { self == .cp437_9x16 ? 9 : 8 }
        public var height: Int { 16 }
    }

    public static func renderHTML(
        document: AnsiDocument,
        rows: Int? = nil,
        fontChoice: FontChoice = .cp437_9x16,
        showHud: Bool = false
    ) -> String {
        let activeRows = rows ?? document.recommendedRows
        let activeCols = document.recommendedCols
        let payload = document.ftelnetPayloadBase64

        let font9b64 = WebAssets.fontCP437_9x16Base64
        let font8b64 = WebAssets.fontCP437_8x16Base64

        var hudHtml = ""
        if showHud, let sauce = document.sauce {
            let titleEscaped = sauce.title.isEmpty ? "Untitled ANSI" : sauce.title
            let authorStr = sauce.author.isEmpty ? "" : "by \(sauce.author)"
            let groupStr = sauce.group.isEmpty ? "" : "(\(sauce.group))"
            let dateStr = sauce.formattedDate ?? ""
            let dimStr = "\(activeCols)x\(activeRows)"

            hudHtml = """
            <div id="sauce-hud">
                <span class="hud-title">\(titleEscaped)</span>
                <span class="hud-meta">\(authorStr) \(groupStr)</span>
                <span class="hud-dim">\(dimStr)</span>
                <span class="hud-date">\(dateStr)</span>
            </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>ANSI QuickLook</title>
            <style>
                \(WebAssets.css)

                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background-color: #0c0a08;
                    color: #e0d8cc;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    overflow: auto;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: flex-start;
                    -webkit-user-select: none;
                    user-select: none;
                }

                #preview-wrapper {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    padding: 20px;
                    box-sizing: border-box;
                }

                #fTelnetContainer {
                    display: inline-block;
                    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.7);
                    border: 1px solid #2a221b;
                    border-radius: 4px;
                    background-color: #000000;
                    image-rendering: pixelated;
                }

                #sauce-hud {
                    margin-bottom: 12px;
                    padding: 6px 14px;
                    background: rgba(30, 25, 20, 0.85);
                    border: 1px solid #4a3c2f;
                    border-radius: 16px;
                    display: flex;
                    gap: 12px;
                    font-size: 12px;
                    align-items: center;
                    backdrop-filter: blur(10px);
                }

                .hud-title {
                    font-weight: 600;
                    color: #ffd27a;
                }

                .hud-meta {
                    color: #a89a8b;
                }

                .hud-dim {
                    background: #2b221a;
                    padding: 2px 6px;
                    border-radius: 4px;
                    color: #79c979;
                    font-family: ui-monospace, monospace;
                }

                .hud-date {
                    color: #7a7065;
                }
            </style>
        </head>
        <body>
            <div id="preview-wrapper">
                \(hudHtml)
                <div id="fTelnetContainer"></div>
            </div>

            <script id="fTelnetScript">
                \(WebAssets.ftelnetJS)
            </script>

            <script>
                // Intercept font requests to load zero-latency base64 inlined CP437 bitmaps
                var FONT_9x16 = 'data:image/png;base64,\(font9b64)';
                var FONT_8x16 = 'data:image/png;base64,\(font8b64)';

                if (typeof CrtFonts !== 'undefined') {
                    CrtFonts.GetLocalUrl = function(font, width, height) {
                        if (width === 8) {
                            return FONT_8x16;
                        }
                        return FONT_9x16;
                    };
                }

                var options = new fTelnetOptions();
                options.SplashScreen = '\(payload)';
                options.ScreenRows = \(activeRows);
                options.ScreenColumns = \(activeCols);
                options.Font = '\(fontChoice.fontName)';
                options.FontSize = '\(fontChoice.width)x\(fontChoice.height)';

                window.client = new fTelnetClient('fTelnetContainer', options);

                function setScreenRows(rows) {
                    var c = document.getElementById('fTelnetContainer');
                    c.innerHTML = '';
                    options.ScreenRows = rows;
                    window.client = new fTelnetClient('fTelnetContainer', options);
                }

                function setFont(width, height) {
                    var c = document.getElementById('fTelnetContainer');
                    c.innerHTML = '';
                    options.FontSize = width + 'x' + height;
                    window.client = new fTelnetClient('fTelnetContainer', options);
                }
            </script>
        </body>
        </html>
        """
    }
}
