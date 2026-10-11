import XCTest
#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
@testable import AnsiCore

final class ViewMenuTests: XCTestCase {
    class TestAppModel: ObservableObject {
        @Published var isSidebarVisible = false
        @Published var zoomLevel: Double = 1.0

        func zoomIn() { zoomLevel = ZoomScale.zoomIn(from: zoomLevel) }
        func zoomOut() { zoomLevel = ZoomScale.zoomOut(from: zoomLevel) }
        func resetZoom() { zoomLevel = 1.0 }
        func setZoom(_ level: Double) { zoomLevel = ZoomScale.clamp(level) }
    }

    func testAppModelZoomTransitions() {
        let model = TestAppModel()
        XCTAssertEqual(model.zoomLevel, 1.0)

        model.zoomIn()
        XCTAssertEqual(model.zoomLevel, 1.25)

        model.zoomIn()
        XCTAssertEqual(model.zoomLevel, 1.5)

        model.zoomOut()
        XCTAssertEqual(model.zoomLevel, 1.25)

        model.resetZoom()
        XCTAssertEqual(model.zoomLevel, 1.0)

        model.zoomOut()
        XCTAssertEqual(model.zoomLevel, 0.75)
    }

    func testZoomBoundaryConditions() {
        let model = TestAppModel()
        model.setZoom(10.0)
        XCTAssertEqual(model.zoomLevel, ZoomScale.maxZoom)

        model.setZoom(0.01)
        XCTAssertEqual(model.zoomLevel, ZoomScale.minZoom)
    }
}
#endif
