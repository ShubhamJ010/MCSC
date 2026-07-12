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

    /// A deferred `deviceStop` is scheduled by `stop()` because stopping a
    /// device synchronously can crash the framework's internal thread. We
    /// keep a reference so `start()` can cancel a *stale* stop that was
    /// scheduled before sleep and would otherwise fire *after* we have
    /// already re-created the (same) trackpad devices on wake — silently
    /// tearing them back down and killing gesture delivery.
    private var pendingStop: DispatchWorkItem?

    func start() {
        // Cancel any in-flight deferred stop from a previous stop()/sleep
        // cycle. Without this, a delayed deviceStop scheduled before sleep
        // can fire after we restart the listener on wake and shut down the
        // freshly re-created trackpad devices.
        pendingStop?.cancel()
        pendingStop = nil

        // If we woke up without a preceding sleep notification, the service
        // can be left "running" against a now-stale device handle. Tear it
        // down and rebuild it. stop() defers its deviceStop, but we cancel
        // that pending work immediately afterwards so it can't kill the
        // devices we are about to re-create.
        if isRunning {
            stop()
            pendingStop?.cancel()
            pendingStop = nil
        }

        guard !isRunning else { return }
        beginListening()
    }

    private func beginListening() {
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

        // Cancel any deferred stop from an earlier cycle before scheduling
        // a new one (e.g. a quick sleep/wake/sleep).
        pendingStop?.cancel()
        pendingStop = nil

        let bridge = MultitouchBridge.shared
        for device in devices {
            bridge.unregisterContactFrameCallback?(device, multitouchCallback)
        }

        // Delay stop to avoid crash in framework's internal thread
        let devicesToStop = devices
        let work = DispatchWorkItem {
            for device in devicesToStop {
                MultitouchBridge.shared.deviceStop?(device)
            }
        }
        pendingStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)

        devices.removeAll()
        isRunning = false
        MultitouchService.shared = nil
        // NOTE: Do NOT null out `onFrame` here. It is configured once by the
        // ViewModel and must survive a stop()/start() cycle so gestures keep
        // working after the system wakes from sleep. (The closure captures
        // the ViewModel weakly, so there is no retain cycle.)
        print("[MultitouchService] Stopped listening")
    }
}

// MARK: - C Callback (free function, bridges back to instance)

nonisolated private func multitouchCallback(
    device: MTDeviceRef?,
    fingers: UnsafeMutableRawPointer?,
    count: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    guard let fingers = fingers, count > 0 else { return 0 }

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

    DispatchQueue.main.async {
        if let service = MultitouchService.shared {
            service.onFrame?(points, timestamp)
        }
    }
    return 0
}
