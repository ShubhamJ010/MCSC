import Cocoa

enum HapticType {
    case swipeLeft
    case swipeRight
    case swipeDown
    case swipeUp
    case twoFingerDoubleTap
    case pinchIn
}

enum HapticService {
    static func perform(_ type: HapticType) {
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch type {
        case .swipeLeft:
            performer.perform(.alignment, performanceTime: .now)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) {
                performer.perform(.levelChange, performanceTime: .now)
            }
        case .swipeRight:
            performer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) {
                performer.perform(.alignment, performanceTime: .now)
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.09) {
                performer.perform(.alignment, performanceTime: .now)
            }
        case .swipeDown:
            performer.perform(.levelChange, performanceTime: .now)
        case .swipeUp:
            performer.perform(.alignment, performanceTime: .now)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.07) {
                performer.perform(.levelChange, performanceTime: .now)
            }
        case .twoFingerDoubleTap:
            performer.perform(.alignment, performanceTime: .now)
        case .pinchIn:
            performer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.08) {
                performer.perform(.levelChange, performanceTime: .now)
            }
        }
    }
}
