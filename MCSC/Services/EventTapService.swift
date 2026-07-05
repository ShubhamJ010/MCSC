import Cocoa

class EventTapService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastEventTime: UInt64 = 0
    
    typealias ShortcutDetectedCallback = (Int64, CGEventFlags, CGPoint) -> Bool
    var onShortcutDetected: ShortcutDetectedCallback?
    var onMagnifyGesture: ((CGFloat, CGPoint) -> Void)?
    
    func start() {
        let eventMask: UInt64 = (1 << 29)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let service = Unmanaged<EventTapService>.fromOpaque(refcon!).takeUnretainedValue()
                
                if type.rawValue == 29 {
                    let field110 = event.getDoubleValueField(CGEventField(rawValue: 110)!)
                    
                    if field110 == 4.0 {
                        let field120 = event.getDoubleValueField(CGEventField(rawValue: 120)!)
                        let now = event.timestamp
                        let location = event.location
                        
                        let gap = now - service.lastEventTime
                        let isNewGesture = service.lastEventTime == 0 || gap > 100_000_000
                        service.lastEventTime = now
                        
                        if isNewGesture {
                            print("[EventTapService] New gesture detected (gap: \(gap)). Skipping first frame.")
                        } else if field120 != 0.0 && field120 != 1.0 {
                            let delta = CGFloat(field120)
                            print("[EventTapService] MAGNIFY: delta=\(delta) at \(location)")
                            service.onMagnifyGesture?(delta, location)
                        }
                    }
                } else if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    let location = event.location
                    
                    if let callback = service.onShortcutDetected, callback(keyCode, flags, location) {
                        return nil
                    }
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    func stop() {
        if let runLoopSource = runLoopSource {
            CFRunLoopSourceInvalidate(runLoopSource)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        lastEventTime = 0
    }
}
