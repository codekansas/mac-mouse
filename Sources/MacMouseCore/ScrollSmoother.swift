import CoreGraphics
import Foundation

public final class ScrollSmoother: NSObject {
    private struct Constants {
        static let syntheticMarker: Int64 = 0x4d4d_5343
        static let timerInterval = 1.0 / 120.0
        static let timerTolerance = 1.0 / 240.0
        static let baseVelocityPerLine = 6.5
        static let minVelocityDamping = 0.84
        static let maxVelocityDamping = 0.94
        static let incomingVelocityRetention = 0.72
        static let maxVelocity = 96.0
        static let stopVelocity = 0.18
        static let burstWindow = 0.14
        static let burstDecay = 0.68
        static let maxBurstScore = 1.8
        static let burstBoostMultiplier = 1.15
    }

    private struct Tuning {
        let baseVelocityPerLine: Double
        let maxVelocity: Double
        let stopVelocity: Double
    }

    private struct AxisState {
        var velocityPxPerTick = 0.0
        var residualPixels = 0.0
        var recentBurstScore = 0.0
        var lastImpulseTime: TimeInterval?
        var lastDirection = 0.0

        mutating func addImpulse(lines: Int64, now: TimeInterval, tuning: Tuning) {
            guard lines != 0 else {
                return
            }

            let lineDelta = Double(lines)
            let direction = lineDelta.sign == .minus ? -1.0 : 1.0

            if velocityPxPerTick != 0, velocityPxPerTick.sign != lineDelta.sign {
                velocityPxPerTick *= 0.25
                recentBurstScore *= 0.25
            }

            if let lastImpulseTime {
                let elapsed = max(0, now - lastImpulseTime)
                let rapidness = max(0, 1 - (elapsed / Constants.burstWindow))
                let directionalWeight = direction == lastDirection ? 1.0 : 0.35
                recentBurstScore *= Constants.burstDecay
                recentBurstScore += rapidness * directionalWeight
                recentBurstScore = min(recentBurstScore, Constants.maxBurstScore)
            } else {
                recentBurstScore = 0
            }

            let burstBoost = 1 + (recentBurstScore * Constants.burstBoostMultiplier)
            let impulse = lineDelta * tuning.baseVelocityPerLine * burstBoost
            velocityPxPerTick = (velocityPxPerTick * Constants.incomingVelocityRetention) + impulse
            velocityPxPerTick = min(max(velocityPxPerTick, -tuning.maxVelocity), tuning.maxVelocity)
            lastImpulseTime = now
            lastDirection = direction
        }

        mutating func emitPixels(tuning: Tuning) -> Int32 {
            residualPixels += velocityPxPerTick
            let emittedPixels = residualPixels.rounded(.towardZero)
            residualPixels -= emittedPixels
            let normalizedVelocity = min(abs(velocityPxPerTick) / tuning.maxVelocity, 1)
            let damping = Constants.minVelocityDamping
                + ((Constants.maxVelocityDamping - Constants.minVelocityDamping) * normalizedVelocity)
            velocityPxPerTick *= damping
            recentBurstScore *= 0.92

            if abs(velocityPxPerTick) < tuning.stopVelocity {
                velocityPxPerTick = 0
                residualPixels = 0
                recentBurstScore = 0
            }

            return Int32(emittedPixels)
        }

        var isIdle: Bool {
            velocityPxPerTick == 0 && residualPixels == 0
        }
    }

    private var verticalAxis = AxisState()
    private var horizontalAxis = AxisState()
    private var emissionTimer: Timer?
    private var activeFlags: CGEventFlags = []
    private let systemScrollSettings = SystemScrollSettings()

    deinit {
        emissionTimer?.invalidate()
    }

    @discardableResult
    public func consume(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.eventSourceUserData) != Constants.syntheticMarker else {
            return false
        }

        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else {
            return false
        }

        let verticalLines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let horizontalLines = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        guard verticalLines != 0 || horizontalLines != 0 else {
            return false
        }

        let now = ProcessInfo.processInfo.systemUptime
        let tuning = currentTuning()
        activeFlags = event.flags
        verticalAxis.addImpulse(lines: verticalLines, now: now, tuning: tuning)
        horizontalAxis.addImpulse(lines: horizontalLines, now: now, tuning: tuning)
        ensureTimer()
        return true
    }

    private func ensureTimer() {
        guard emissionTimer == nil else {
            return
        }

        emissionTimer = Timer.scheduledTimer(
            timeInterval: Constants.timerInterval,
            target: self,
            selector: #selector(emitStep),
            userInfo: nil,
            repeats: true
        )
        emissionTimer?.tolerance = Constants.timerTolerance
        if let emissionTimer {
            RunLoop.main.add(emissionTimer, forMode: .common)
        }
    }

    @objc
    private func emitStep() {
        let tuning = currentTuning()
        let verticalPixels = verticalAxis.emitPixels(tuning: tuning)
        let horizontalPixels = horizontalAxis.emitPixels(tuning: tuning)

        if verticalPixels != 0 || horizontalPixels != 0 {
            postScroll(verticalPixels: verticalPixels, horizontalPixels: horizontalPixels)
        }

        if verticalAxis.isIdle && horizontalAxis.isIdle {
            emissionTimer?.invalidate()
            emissionTimer = nil
        }
    }

    // Synthetic pixel scroll events produce smaller, more frequent deltas than
    // a mechanical wheel, which feels substantially closer to trackpad scrolling.
    private func postScroll(verticalPixels: Int32, horizontalPixels: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: verticalPixels,
            wheel2: horizontalPixels,
            wheel3: 0
        ) else {
            return
        }

        event.flags = activeFlags
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: Constants.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    private func currentTuning() -> Tuning {
        let speedMultiplier = systemScrollSettings.speedMultiplier()
        return Tuning(
            baseVelocityPerLine: Constants.baseVelocityPerLine * speedMultiplier,
            maxVelocity: Constants.maxVelocity * speedMultiplier,
            stopVelocity: max(Constants.stopVelocity * speedMultiplier, 0.08)
        )
    }
}
