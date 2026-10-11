import Foundation

public struct AnsiDocument: Equatable, Sendable {
    public let rawData: Data
    public let sanitizedAnsiData: Data
    public let sauce: SauceRecord?
    public let estimatedRows: Int
    public let recommendedRows: Int
    public let recommendedCols: Int

    public init(data: Data) {
        self.rawData = data

        if let parsed = SauceParser.parse(data: data) {
            self.sauce = parsed.record

            // Trim data before EOF (0x1A) and SAUCE block
            var endOffset = parsed.sauceOffset
            if let comntCount = parsed.record.commentCount as UInt8?, comntCount > 0 {
                let comntLen = 5 + (Int(comntCount) * 64)
                let comntOffset = parsed.sauceOffset - comntLen
                if comntOffset >= 0 {
                    endOffset = comntOffset
                }
            }

            // Strip trailing EOF (0x1A) if present before SAUCE
            var trimmedData = data.prefix(endOffset)
            while let last = trimmedData.last, last == 0x1A || last == 0x00 {
                trimmedData = trimmedData.dropLast()
            }
            self.sanitizedAnsiData = Data(trimmedData)

            let rows = Int(parsed.record.height)
            let cols = Int(parsed.record.width)
            self.recommendedCols = cols > 0 ? cols : 80

            let est = AnsiDocument.calculateEstimatedRows(from: self.sanitizedAnsiData)
            self.estimatedRows = est

            if rows > 0 {
                self.recommendedRows = rows > 25 ? max(rows, 50) : 25
            } else if est > 25 {
                self.recommendedRows = max(est, 50)
            } else {
                self.recommendedRows = 25
            }
        } else {
            self.sauce = nil

            // Find first EOF (0x1A) byte if present
            var endOffset = data.count
            if let eofIdx = data.firstIndex(of: 0x1A) {
                endOffset = eofIdx
            }
            var trimmedData = data.prefix(endOffset)
            while let last = trimmedData.last, last == 0x00 {
                trimmedData = trimmedData.dropLast()
            }
            self.sanitizedAnsiData = Data(trimmedData)

            let est = AnsiDocument.calculateEstimatedRows(from: self.sanitizedAnsiData)
            self.estimatedRows = est
            self.recommendedCols = 80
            self.recommendedRows = est > 25 ? 50 : 25
        }
    }

    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(data: data)
    }

    /// Base64-encoded string prepended with clear screen and reset escape sequences for fTelnet.
    public var ftelnetPayloadBase64: String {
        let initSequence = Data([0x1B, 0x5B, 0x30, 0x6D, 0x1B, 0x5B, 0x32, 0x4A, 0x1B, 0x5B, 0x48]) // \x1b[0m\x1b[2J\x1b[H
        var combined = initSequence
        combined.append(sanitizedAnsiData)
        return combined.base64EncodedString()
    }

    private static func calculateEstimatedRows(from data: Data) -> Int {
        var newlines = 0
        for byte in data {
            if byte == 0x0A { // \n
                newlines += 1
            }
        }
        return max(1, newlines)
    }
}
