import Foundation

/// Snapshot of a single touch point per frame.
struct TouchPoint {
    let identifier: Int32
    let state: Int32
    let normalizedX: Float
    let normalizedY: Float
    let size: Float
}

/// Thin wrapper around MultitouchSupport.framework.
/// - Starts/stops the trackpad device
/// - Converts raw `Finger` structs into clean `TouchPoint` values
/// - Forwards frames via callback (no gesture logic here)
class MultitouchService {
    typealias FrameCallback = ([TouchPoint], Double) -> Void

    private var devices: [MTDeviceRef] = []
    private var isRunning = false

    /// Set before calling start(). Uses weak-safe pattern via ViewModel.
    var onFrame: FrameCallback?

    // Static ref to self for C callback (only one instance ever exists)
    fileprivate static var shared: MultitouchService?

    func start() {
        guard !isRunning else { return }
        
        let bridge = MultitouchBridge.shared
        guard bridge.isLoaded else {
            print("[MultitouchService] Cannot start, MultitouchBridge is not loaded")
            return
        }
        
        MultitouchService.shared = self

        guard let listRef = bridge.deviceCreateList?() else {
            print("[MultitouchService] Failed to create device list")
            return
        }
        let deviceList = listRef.takeRetainedValue() as NSArray
        
        for device in deviceList {
            let ref = Unmanaged<AnyObject>.passUnretained(device as AnyObject).toOpaque()
            let mtRef = UnsafeMutableRawPointer(ref)
            devices.append(mtRef)
            bridge.registerContactFrameCallback?(mtRef, multitouchCallback)
            bridge.deviceStart?(mtRef, 0)
        }
        isRunning = true
        print("[MultitouchService] Started listening on \(devices.count) trackpad device(s)")
    }

    func stop() {
        guard isRunning else { return }
        
        let bridge = MultitouchBridge.shared
        for device in devices {
            bridge.unregisterContactFrameCallback?(device, multitouchCallback)
        }
        
        // Delay stop to avoid crash in framework's internal thread
        let devicesToStop = devices
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for device in devicesToStop {
                bridge.deviceStop?(device)
            }
        }
        
        devices.removeAll()
        isRunning = false
        MultitouchService.shared = nil
        onFrame = nil
        print("[MultitouchService] Stopped listening")
    }
}

// MARK: - C Callback (free function, bridges back to instance)

private func multitouchCallback(
    device: MTDeviceRef?,
    fingers: UnsafeMutableRawPointer?,
    count: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    guard let fingers = fingers, count > 0,
          let service = MultitouchService.shared else { return 0 }

    let fingerPtr = fingers.assumingMemoryBound(to: Finger.self)
    var points: [TouchPoint] = []
    points.reserveCapacity(Int(count))

    for i in 0..<Int(count) {
        let f = fingerPtr[i]
        // Only include fingers that are actively touching/hovering
        if f.state >= 4 {
            points.append(TouchPoint(
                identifier: f.identifier,
                state: f.state,
                normalizedX: f.normalizedX,
                normalizedY: f.normalizedY,
                size: f.size
            ))
        }
    }

    service.onFrame?(points, timestamp)
    return 0
}
