import Foundation
import QuickLookUI
import UniformTypeIdentifiers
import AnsiCore

@objc(PreviewProvider)
public class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    public func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let doc = try AnsiDocument(contentsOf: request.fileURL)
        let html = AnsiPreviewTemplate.renderHTML(
            document: doc,
            rows: doc.recommendedRows,
            fontChoice: .cp437_9x16,
            showHud: true
        )
        guard let data = html.data(using: .utf8) else {
            throw CocoaError(.fileReadUnknown)
        }

        let width = Double(max(760, (doc.recommendedCols * 9) + 40))
        let height = Double(max(450, (doc.recommendedRows * 16) + 90))
        let size = CGSize(width: width, height: height)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: size) { _ in
            return data
        }
        if let title = doc.sauce?.title, !title.isEmpty {
            reply.title = title
        }
        return reply
    }
}
