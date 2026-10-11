import Foundation

/// Defines scale levels, presets, and progression math for ANSI preview zoom.
public struct ZoomScale: Sendable {
    public static let presets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
    public static let defaultZoom: Double = 1.0
    public static let minZoom: Double = 0.25
    public static let maxZoom: Double = 5.0

    /// Clamps zoom level between minZoom and maxZoom, rounding to two decimal places.
    public static func clamp(_ level: Double) -> Double {
        let clamped = max(minZoom, min(level, maxZoom))
        return (clamped * 100).rounded() / 100
    }

    /// Advances to the next preset above `current`, or increments smoothly up to maxZoom.
    public static func zoomIn(from current: Double) -> Double {
        if let next = presets.first(where: { $0 > current + 0.001 }) {
            return next
        }
        return clamp(current * 1.25)
    }

    /// Retreats to the next preset below `current`, or decrements smoothly down to minZoom.
    public static func zoomOut(from current: Double) -> Double {
        if let prev = presets.last(where: { $0 < current - 0.001 }) {
            return prev
        }
        return clamp(current / 1.25)
    }

    /// Formats zoom level as an integer percentage string (e.g. "100%", "125%").
    public static func formattedPercentage(_ level: Double) -> String {
        "\(Int(round(level * 100)))%"
    }
}
