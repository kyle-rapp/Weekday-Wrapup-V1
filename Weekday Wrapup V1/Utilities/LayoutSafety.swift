import CoreGraphics

enum LayoutSafety {
    static func safeCGFloat(_ value: CGFloat, fallback: CGFloat = 0) -> CGFloat {
        value.isFinite ? value : fallback
    }

    static func safeProgress(_ value: Double, fallback: Double = 0) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, 0), 1)
    }
}
