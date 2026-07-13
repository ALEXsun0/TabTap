import Foundation

public struct PointerPosition: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func distanceSquared(to other: PointerPosition) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}

public struct DoubleClickRecognizer: Sendable {
    private struct Click: Sendable {
        let timestamp: TimeInterval
        let position: PointerPosition
        let targetID: String
    }

    public let maximumInterval: TimeInterval
    public let maximumDistance: Double
    private var previousClick: Click?

    public init(maximumInterval: TimeInterval = 0.45, maximumDistance: Double = 6) {
        self.maximumInterval = maximumInterval
        self.maximumDistance = maximumDistance
    }

    public mutating func registerClick(
        timestamp: TimeInterval,
        position: PointerPosition,
        targetID: String
    ) -> Bool {
        if let previousClick {
            let interval = timestamp - previousClick.timestamp
            let maximumDistanceSquared = maximumDistance * maximumDistance
            let isMatchingClick = interval >= 0
                && interval <= maximumInterval
                && previousClick.targetID == targetID
                && previousClick.position.distanceSquared(to: position) <= maximumDistanceSquared

            if isMatchingClick {
                self.previousClick = nil
                return true
            }
        }

        previousClick = Click(
            timestamp: timestamp,
            position: position,
            targetID: targetID
        )
        return false
    }

    public mutating func reset() {
        previousClick = nil
    }
}
