import Foundation

/// Represents a parsed ACiD SAUCE (Standard Architecture for Universal Comment Extensions) v00.5 record.
public struct SauceRecord: Equatable, Sendable {
    public let title: String
    public let author: String
    public let group: String
    public let date: String
    public let fileSize: UInt32
    public let dataType: UInt8
    public let fileType: UInt8
    public let width: UInt16
    public let height: UInt16
    public let tInfo3: UInt16
    public let tInfo4: UInt16
    public let commentCount: UInt8
    public let flags: UInt8
    public let comments: [String]

    public init(
        title: String,
        author: String,
        group: String,
        date: String,
        fileSize: UInt32,
        dataType: UInt8,
        fileType: UInt8,
        width: UInt16,
        height: UInt16,
        tInfo3: UInt16 = 0,
        tInfo4: UInt16 = 0,
        commentCount: UInt8 = 0,
        flags: UInt8 = 0,
        comments: [String] = []
    ) {
        self.title = title
        self.author = author
        self.group = group
        self.date = date
        self.fileSize = fileSize
        self.dataType = dataType
        self.fileType = fileType
        self.width = width
        self.height = height
        self.tInfo3 = tInfo3
        self.tInfo4 = tInfo4
        self.commentCount = commentCount
        self.flags = flags
        self.comments = comments
    }

    /// Formatted date string (YYYY-MM-DD) if available.
    public var formattedDate: String? {
        guard date.count == 8 else { return nil }
        let year = date.prefix(4)
        let month = date.dropFirst(4).prefix(2)
        let day = date.suffix(2)
        return "\(year)-\(month)-\(day)"
    }
}

public enum SauceParser {
    private static let sauceSignature = Data("SAUCE00".utf8)
    private static let comntSignature = Data("COMNT".utf8)
    public static let sauceRecordLength = 128

    /// Attempts to parse a SAUCE record from the tail of raw binary data.
    public static func parse(data: Data) -> (record: SauceRecord, sauceOffset: Int)? {
        guard data.count >= sauceRecordLength else { return nil }

        // Find the SAUCE00 signature starting from the end
        // Standard SAUCE record is exactly the last 128 bytes, or right after EOF (0x1A)
        let searchStart = max(0, data.count - 1024 * 16)
        guard let range = data.range(of: sauceSignature, in: searchStart..<data.count) else {
            return nil
        }

        let sauceOffset = range.lowerBound
        guard data.count - sauceOffset >= sauceRecordLength else {
            return nil
        }

        let sub = data.subdata(in: sauceOffset..<(sauceOffset + sauceRecordLength))

        func readString(offset: Int, length: Int) -> String {
            let slice = sub.subdata(in: offset..<(offset + length))
            return String(data: slice, encoding: .isoLatin1)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        func readUInt16(offset: Int) -> UInt16 {
            let b0 = UInt16(sub[offset])
            let b1 = UInt16(sub[offset + 1])
            return b0 | (b1 << 8)
        }

        func readUInt32(offset: Int) -> UInt32 {
            let b0 = UInt32(sub[offset])
            let b1 = UInt32(sub[offset + 1])
            let b2 = UInt32(sub[offset + 2])
            let b3 = UInt32(sub[offset + 3])
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        }

        let title = readString(offset: 7, length: 35)
        let author = readString(offset: 42, length: 20)
        let group = readString(offset: 62, length: 20)
        let date = readString(offset: 82, length: 8)
        let fileSize = readUInt32(offset: 90)
        let dataType = sub[94]
        let fileType = sub[95]
        let width = readUInt16(offset: 96)
        let height = readUInt16(offset: 98)
        let tInfo3 = readUInt16(offset: 100)
        let tInfo4 = readUInt16(offset: 102)
        let commentCount = sub[104]
        let flags = sub[105]

        // Parse optional COMNT block
        var comments: [String] = []
        if commentCount > 0 {
            let expectedComntLen = 5 + (Int(commentCount) * 64)
            let comntOffset = sauceOffset - expectedComntLen
            if comntOffset >= 0 && data.subdata(in: comntOffset..<(comntOffset + 5)) == comntSignature {
                for i in 0..<Int(commentCount) {
                    let lineStart = comntOffset + 5 + (i * 64)
                    let lineEnd = lineStart + 64
                    if lineEnd <= sauceOffset {
                        let lineData = data.subdata(in: lineStart..<lineEnd)
                        if let str = String(data: lineData, encoding: .isoLatin1) {
                            comments.append(str.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                }
            }
        }

        let record = SauceRecord(
            title: title,
            author: author,
            group: group,
            date: date,
            fileSize: fileSize,
            dataType: dataType,
            fileType: fileType,
            width: width,
            height: height,
            tInfo3: tInfo3,
            tInfo4: tInfo4,
            commentCount: commentCount,
            flags: flags,
            comments: comments
        )

        return (record, sauceOffset)
    }
}
