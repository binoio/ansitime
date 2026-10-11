import XCTest
@testable import AnsiCore

final class AnsiDocumentTests: XCTestCase {
    func testSanitizesEofAndSauce() {
        var raw = Data("Hello ANSI Art\r\nLine 2\r\n".utf8)
        let bodyLength = raw.count
        raw.append(0x1A) // EOF

        // Append 128-byte dummy SAUCE
        var sauce = Data("SAUCE00".utf8)
        sauce.append(Data("Sample Title                       ".utf8))
        sauce.append(Data("Artist              ".utf8))
        sauce.append(Data("Group               ".utf8))
        sauce.append(Data("20261011".utf8))
        sauce.append(contentsOf: [UInt8(bodyLength), 0, 0, 0])
        sauce.append(1) // DataType
        sauce.append(1) // FileType
        sauce.append(contentsOf: [80, 0]) // 80 cols
        sauce.append(contentsOf: [25, 0]) // 25 rows
        sauce.append(contentsOf: [0, 0])
        sauce.append(contentsOf: [0, 0])
        sauce.append(0) // Comments
        sauce.append(0) // Flags
        sauce.append(Data(repeating: 0, count: 22))
        raw.append(sauce)

        let doc = AnsiDocument(data: raw)
        XCTAssertNotNil(doc.sauce)
        XCTAssertEqual(doc.sanitizedAnsiData.count, bodyLength)
        XCTAssertEqual(String(data: doc.sanitizedAnsiData, encoding: .utf8), "Hello ANSI Art\r\nLine 2\r\n")
        XCTAssertEqual(doc.recommendedRows, 25)
        XCTAssertEqual(doc.recommendedCols, 80)
        XCTAssertFalse(doc.ftelnetPayloadBase64.isEmpty)
    }

    func testPlainAnsiWithoutSauce() {
        let plain = "Text line 1\nText line 2\nText line 3\n"
        let data = Data(plain.utf8)
        let doc = AnsiDocument(data: data)

        XCTAssertNil(doc.sauce)
        XCTAssertEqual(doc.sanitizedAnsiData, data)
        XCTAssertEqual(doc.recommendedCols, 80)
        XCTAssertEqual(doc.recommendedRows, 25)
    }

    func testTallAnsiRowMapping() {
        var raw = Data("Tall ANSI\r\n".utf8)
        let bodyLength = raw.count
        raw.append(0x1A)

        var sauce = Data("SAUCE00".utf8)
        sauce.append(Data("Tall Artwork                       ".utf8))
        sauce.append(Data("Artist              ".utf8))
        sauce.append(Data("Group               ".utf8))
        sauce.append(Data("20261011".utf8))
        sauce.append(contentsOf: [UInt8(bodyLength), 0, 0, 0])
        sauce.append(1) // DataType
        sauce.append(1) // FileType
        sauce.append(contentsOf: [80, 0]) // 80 cols
        sauce.append(contentsOf: [30, 0]) // 30 rows
        sauce.append(contentsOf: [0, 0])
        sauce.append(contentsOf: [0, 0])
        sauce.append(0)
        sauce.append(0)
        sauce.append(Data(repeating: 0, count: 22))
        raw.append(sauce)

        let doc = AnsiDocument(data: raw)
        XCTAssertEqual(doc.recommendedRows, 50)
    }
}
