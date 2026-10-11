import XCTest
@testable import AnsiCore

final class ZoomScaleTests: XCTestCase {
    func testDefaultZoomIsOne() {
        XCTAssertEqual(ZoomScale.defaultZoom, 1.0)
    }

    func testZoomInStepsThroughPresets() {
        var current = 1.0
        current = ZoomScale.zoomIn(from: current)
        XCTAssertEqual(current, 1.25)

        current = ZoomScale.zoomIn(from: current)
        XCTAssertEqual(current, 1.5)

        current = ZoomScale.zoomIn(from: current)
        XCTAssertEqual(current, 2.0)

        current = ZoomScale.zoomIn(from: current)
        XCTAssertEqual(current, 3.0)

        current = ZoomScale.zoomIn(from: current)
        XCTAssertEqual(current, 4.0)
    }

    func testZoomOutStepsThroughPresets() {
        var current = 1.0
        current = ZoomScale.zoomOut(from: current)
        XCTAssertEqual(current, 0.75)

        current = ZoomScale.zoomOut(from: current)
        XCTAssertEqual(current, 0.5)
    }

    func testArbitraryZoomSnapsToNextOrPreviousPreset() {
        // Between 1.0 and 1.25
        XCTAssertEqual(ZoomScale.zoomIn(from: 1.1), 1.25)
        XCTAssertEqual(ZoomScale.zoomOut(from: 1.1), 1.0)

        // Between 0.5 and 0.75
        XCTAssertEqual(ZoomScale.zoomIn(from: 0.6), 0.75)
        XCTAssertEqual(ZoomScale.zoomOut(from: 0.6), 0.5)
    }

    func testClampingLimits() {
        XCTAssertEqual(ZoomScale.clamp(0.1), ZoomScale.minZoom)
        XCTAssertEqual(ZoomScale.clamp(10.0), ZoomScale.maxZoom)
        XCTAssertEqual(ZoomScale.clamp(1.2345), 1.23)
    }

    func testFormattedPercentage() {
        XCTAssertEqual(ZoomScale.formattedPercentage(1.0), "100%")
        XCTAssertEqual(ZoomScale.formattedPercentage(0.5), "50%")
        XCTAssertEqual(ZoomScale.formattedPercentage(1.25), "125%")
        XCTAssertEqual(ZoomScale.formattedPercentage(4.0), "400%")
    }
}
