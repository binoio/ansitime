import XCTest
@testable import AnsiCore

final class SauceRecordTests: XCTestCase {
    func testParseEmptyDataReturnsNil() {
        let empty = Data()
        XCTAssertNil(SauceParser.parse(data: empty))
    }

    func testParseShortDataReturnsNil() {
        let short = Data(repeating: 0x41, count: 64)
        XCTAssertNil(SauceParser.parse(data: short))
    }

    func testSyntheticSauceParsing() {
        var data = Data(repeating: 0x20, count: 100) // 100 bytes of ANSI text
        data.append(0x1A) // EOF

        // Build 128-byte SAUCE
        var sauce = Data("SAUCE00".utf8) // 7 bytes
        sauce.append(Data("My Test ANSI Title                 ".utf8)) // 35 bytes
        sauce.append(Data("Artist Name         ".utf8)) // 20 bytes
        sauce.append(Data("Release Group       ".utf8)) // 20 bytes
        sauce.append(Data("20261011".utf8)) // 8 bytes
        sauce.append(contentsOf: [100, 0, 0, 0]) // FileSize = 100 (4 bytes)
        sauce.append(1) // DataType = Character
        sauce.append(1) // FileType = ANSI
        sauce.append(contentsOf: [80, 0]) // Width = 80 (2 bytes)
        sauce.append(contentsOf: [25, 0]) // Height = 25 (2 bytes)
        sauce.append(contentsOf: [0, 0]) // TInfo3
        sauce.append(contentsOf: [0, 0]) // TInfo4
        sauce.append(0) // Comments count = 0
        sauce.append(0) // Flags
        sauce.append(Data(repeating: 0, count: 22)) // Filler 22 bytes

        XCTAssertEqual(sauce.count, 128)
        data.append(sauce)

        let result = SauceParser.parse(data: data)
        XCTAssertNotNil(result)

        guard let (record, offset) = result else { return }
        XCTAssertEqual(offset, 101)
        XCTAssertEqual(record.title, "My Test ANSI Title")
        XCTAssertEqual(record.author, "Artist Name")
        XCTAssertEqual(record.group, "Release Group")
        XCTAssertEqual(record.date, "20261011")
        XCTAssertEqual(record.formattedDate, "2026-10-11")
        XCTAssertEqual(record.fileSize, 100)
        XCTAssertEqual(record.dataType, 1)
        XCTAssertEqual(record.fileType, 1)
        XCTAssertEqual(record.width, 80)
        XCTAssertEqual(record.height, 25)
    }

    func testSyntheticCommentsParsing() {
        var data = Data("ANSI content".utf8)
        data.append(0x1A)

        // Build COMNT block with 1 line (5 + 64 = 69 bytes)
        data.append(Data("COMNT".utf8))
        var commentLine = Data("This is an authentic test comment line for SAUCE verification.".utf8)
        commentLine.append(Data(repeating: 0x20, count: 64 - commentLine.count))
        data.append(commentLine)

        // Build 128-byte SAUCE with commentCount = 1
        var sauce = Data("SAUCE00".utf8)
        sauce.append(Data(repeating: 0x20, count: 35))
        sauce.append(Data(repeating: 0x20, count: 20))
        sauce.append(Data(repeating: 0x20, count: 20))
        sauce.append(Data("20261011".utf8))
        sauce.append(contentsOf: [12, 0, 0, 0])
        sauce.append(1) // DataType
        sauce.append(1) // FileType
        sauce.append(contentsOf: [80, 0]) // Width
        sauce.append(contentsOf: [50, 0]) // Height
        sauce.append(contentsOf: [0, 0])
        sauce.append(contentsOf: [0, 0])
        sauce.append(1) // Comments = 1
        sauce.append(0) // Flags
        sauce.append(Data(repeating: 0, count: 22))
        data.append(sauce)

        let result = SauceParser.parse(data: data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.record.comments.count, 1)
        XCTAssertEqual(result?.record.comments.first, "This is an authentic test comment line for SAUCE verification.")
    }
}
