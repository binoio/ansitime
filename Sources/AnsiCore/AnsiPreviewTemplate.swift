import Foundation

public struct AnsiPreviewTemplate: Sendable {
    public enum FontChoice: String, CaseIterable, Sendable {
        case cp437_9x16 = "CP437 (9x16)"
        case cp437_8x16 = "CP437 (8x16)"

        public var fontName: String {
            switch self {
            case .cp437_9x16: return "CP437_9x16"
            case .cp437_8x16: return "CP437_8x16"
            }
        }
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
                    margin: auto;
                    padding: 24px;
                    box-sizing: border-box;
                }

                #fTelnetContainer {
                    display: inline-block;
                    box-shadow: 0 16px 48px rgba(0, 0, 0, 0.9), 0 0 0 1px #2a221b;
                    border-radius: 4px;
                    background-color: #000000;
                    image-rendering: pixelated;
                    overflow: hidden;
                }

                /* Hide all client chrome: status bar, connect buttons, scrollback toolbar */
                .fTelnetStatusBar,
                .fTelnetButtons,
                .fTelnetFocusWarning,
                .fTelnetScrollback,
                .fTelnetInitMessage {
                    display: none !important;
                    visibility: hidden !important;
                    height: 0 !important;
                    overflow: hidden !important;
                }

                #sauce-hud {
                    margin-bottom: 14px;
                    padding: 6px 16px;
                    background: rgba(30, 25, 20, 0.9);
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
                var TARGET_WIDTH = \(fontChoice.width);
                var TARGET_HEIGHT = \(fontChoice.height);
                var TARGET_FONT_NAME = '\(fontChoice.fontName)';

                var FONT_9x16 = 'data:image/png;base64,\(font9b64)';
                var FONT_8x16 = 'data:image/png;base64,\(font8b64)';

                // Bulletproof font resolution: lock dimensions to target width/height
                if (typeof CrtFonts !== 'undefined') {
                    CrtFonts.GetBestFit = function(font, maxWidth, maxHeight) {
                        return new Point(TARGET_WIDTH, TARGET_HEIGHT);
                    };

                    CrtFonts.GetLocalUrl = function(font, width, height) {
                        if (TARGET_WIDTH === 8 || width === 8) {
                            return FONT_8x16;
                        }
                        return FONT_9x16;
                    };
                }

                // Override Crt prototype to lock font size and eliminate dynamic downscaling
                if (typeof Crt !== 'undefined' && Crt.prototype) {
                    Crt.prototype.AllowDynamicFontResize = false;
                    Crt.prototype.OnResize = function() {
                        // Prevent font downscaling or canvas resizing on window / sidebar resize
                    };
                    Crt.prototype.SetFont = function(font) {
                        return this._Font.Load(TARGET_FONT_NAME, TARGET_WIDTH, TARGET_HEIGHT);
                    };
                }

                var options = new fTelnetOptions();
                options.SplashScreen = '\(payload)';
                options.ScreenRows = \(activeRows);
                options.ScreenColumns = \(activeCols);
                options.Font = TARGET_FONT_NAME;

                window.client = new fTelnetClient('fTelnetContainer', options);
                if (window.client) {
                    if (window.client._Crt) {
                        window.client._Crt.AllowDynamicFontResize = false;
                        window.client._Crt.OnResize = function() {};
                    }
                    if (window.client._StatusBar) {
                        window.client._StatusBar.style.display = 'none';
                        if (window.client._StatusBar.parentNode) {
                            window.client._StatusBar.parentNode.removeChild(window.client._StatusBar);
                        }
                    }
                }
            </script>
        </body>
        </html>
        """
    }
}
