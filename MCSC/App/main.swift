import Cocoa

/// Entry point. Creates the `AppDelegate` on the main actor and hands it to
/// the shared `NSApplication` before calling `NSApplicationMain`, which runs
/// the main event loop for the rest of the process lifetime.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
