import Cocoa

class GestureRecognitionService {
    struct Config {
        static let magnitudeThreshold: CGFloat = -0.3
        static let liftTimeoutSeconds: TimeInterval = 0.4
        static let cooldownSeconds: TimeInterval = 0.8
    }
    
    private enum State {
        case idle
        case tracking(startLocation: CGPoint, accumulatedMagnitude: CGFloat, lastEventTime: TimeInterval, hapticFired: Bool)
    }
    
    private var state: State = .idle
    private var cooldownUntil: TimeInterval = 0
    
    var onPinchInCompleted: ((CGPoint) -> Void)?
    
    func processMagnification(delta: CGFloat, at location: CGPoint) {
        let now = Date().timeIntervalSince1970
        
        if now < cooldownUntil {
            return
        }
        
        switch state {
        case .idle:
            state = .tracking(startLocation: location, accumulatedMagnitude: delta, lastEventTime: now, hapticFired: false)
            scheduleTimeoutCheck()
        case .tracking(let startLocation, let accumulatedMagnitude, _, let hapticFired):
            let newAccumulated = accumulatedMagnitude + delta
            if !hapticFired && newAccumulated <= Config.magnitudeThreshold {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }
                state = .tracking(startLocation: startLocation, accumulatedMagnitude: newAccumulated, lastEventTime: now, hapticFired: true)
            } else {
                state = .tracking(startLocation: startLocation, accumulatedMagnitude: newAccumulated, lastEventTime: now, hapticFired: hapticFired)
            }
        }
    }
    
    private func scheduleTimeoutCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.liftTimeoutSeconds) { [weak self] in
            self?.checkTimeout()
        }
    }
    
    private func checkTimeout() {
        let now = Date().timeIntervalSince1970
        guard case .tracking(let startLocation, let accumulatedMagnitude, let lastEventTime, _) = state else {
            return
        }
        
        let elapsed = now - lastEventTime
        if elapsed >= Config.liftTimeoutSeconds {
            if accumulatedMagnitude <= Config.magnitudeThreshold {
                onPinchInCompleted?(startLocation)
                cooldownUntil = now + Config.cooldownSeconds
            }
            state = .idle
        } else {
            let remaining = Config.liftTimeoutSeconds - elapsed
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.checkTimeout()
            }
        }
    }
    
    func stop() {
        state = .idle
        onPinchInCompleted = nil
    }
}
