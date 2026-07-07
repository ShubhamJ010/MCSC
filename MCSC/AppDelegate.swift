import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: ShortcutViewModel?
    private var statusItem: NSStatusItem?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusBar()
        
        let eventTap = EventTapService()
        let accessibility = AccessibilityService()
        let missionControl = MissionControlService()
        let launchAtLogin = LaunchAtLoginService()
        
        viewModel = ShortcutViewModel(eventTapService: eventTap, 
                                      accessibilityService: accessibility, 
                                      missionControlService: missionControl,
                                      launchAtLoginService: launchAtLogin)
        
        // Refresh status bar menu now that view model is ready
        setupStatusBar()
        
        // Request accessibility permissions if needed
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            viewModel?.start()
        } else {
            print("Waiting for accessibility permissions...")
            // Poll for trust or wait for a relaunch
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    self?.viewModel?.start()
                    timer.invalidate()
                }
            }
        }
        
        // Observe sleep/wake to recreate event tap
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("System sleeping - stopping event tap")
            self?.viewModel?.stop()
        }
        
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("System woke up - restarting event tap")
            self?.viewModel?.start()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "command.circle", accessibilityDescription: "MCSC")
        }
        
        let menu = NSMenu()
        
        let cmdWItem = NSMenuItem(title: "Cmd + W", action: #selector(toggleCmdW), keyEquivalent: "w")
        cmdWItem.state = .on
        menu.addItem(cmdWItem)
        
        let cmdQItem = NSMenuItem(title: "Cmd + Q", action: #selector(toggleCmdQ), keyEquivalent: "q")
        cmdQItem.state = .on
        menu.addItem(cmdQItem)
        
        let cmdMItem = NSMenuItem(title: "Cmd + M", action: #selector(toggleCmdM), keyEquivalent: "m")
        cmdMItem.state = .on
        menu.addItem(cmdMItem)
        
        let cmdHItem = NSMenuItem(title: "Cmd + H", action: #selector(toggleCmdH), keyEquivalent: "h")
        cmdHItem.state = .on
        menu.addItem(cmdHItem)
        
        let cmdSpaceItem = NSMenuItem(title: "Cmd + Space Fix", action: #selector(toggleCmdSpace), keyEquivalent: " ")
        cmdSpaceItem.state = .on
        menu.addItem(cmdSpaceItem)
        
        let gesturesItem = NSMenuItem(title: "Enable Gestures", action: #selector(toggleGestures), keyEquivalent: "")
        gesturesItem.state = (viewModel?.isGesturesEnabled ?? true) ? .on : .off
        
        let gesturesSubmenu = NSMenu()
        let swipeLeftItem = NSMenuItem(title: "Swipe Left → Close", action: #selector(toggleSwipeLeft), keyEquivalent: "")
        swipeLeftItem.state = (viewModel?.isSwipeLeftEnabled ?? true) ? .on : .off
        gesturesSubmenu.addItem(swipeLeftItem)

        let swipeRightItem = NSMenuItem(title: "Swipe Right → Reopen Tab", action: #selector(toggleSwipeRight), keyEquivalent: "")
        swipeRightItem.state = (viewModel?.isSwipeRightEnabled ?? true) ? .on : .off
        gesturesSubmenu.addItem(swipeRightItem)

        let swipeDownItem = NSMenuItem(title: "Swipe Down → Fullscreen", action: #selector(toggleSwipeDown), keyEquivalent: "")
        swipeDownItem.state = (viewModel?.isSwipeDownEnabled ?? true) ? .on : .off
        gesturesSubmenu.addItem(swipeDownItem)

        let swipeUpItem = NSMenuItem(title: "Swipe Up → Minimize", action: #selector(toggleSwipeUp), keyEquivalent: "")
        swipeUpItem.state = (viewModel?.isSwipeUpEnabled ?? true) ? .on : .off
        gesturesSubmenu.addItem(swipeUpItem)

        let twoFingerTapItem = NSMenuItem(title: "2-Finger Double Tap → Resize", action: #selector(toggleTwoFingerDoubleTap), keyEquivalent: "")
        twoFingerTapItem.state = (viewModel?.isTwoFingerDoubleTapEnabled ?? true) ? .on : .off
        gesturesSubmenu.addItem(twoFingerTapItem)

        gesturesItem.submenu = gesturesSubmenu
        
        menu.addItem(gesturesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "l")
        launchAtLoginItem.state = (viewModel?.isLaunchAtLoginEnabled ?? false) ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MCSC", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "Q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleCmdW(_ sender: NSMenuItem) { handleToggle(sender, key: .cmdW) }
    @objc private func toggleCmdQ(_ sender: NSMenuItem) { handleToggle(sender, key: .cmdQ) }
    @objc private func toggleCmdM(_ sender: NSMenuItem) { handleToggle(sender, key: .cmdM) }
    @objc private func toggleCmdH(_ sender: NSMenuItem) { handleToggle(sender, key: .cmdH) }
    @objc private func toggleCmdSpace(_ sender: NSMenuItem) { handleToggle(sender, key: .cmdSpace) }
    @objc private func toggleGestures(_ sender: NSMenuItem) { handleToggle(sender, key: .gestures) }
    @objc private func toggleSwipeLeft(_ sender: NSMenuItem) { handleToggle(sender, key: .swipeLeft) }
    @objc private func toggleSwipeRight(_ sender: NSMenuItem) { handleToggle(sender, key: .swipeRight) }
    @objc private func toggleSwipeDown(_ sender: NSMenuItem) { handleToggle(sender, key: .swipeDown) }
    @objc private func toggleSwipeUp(_ sender: NSMenuItem) { handleToggle(sender, key: .swipeUp) }
    @objc private func toggleTwoFingerDoubleTap(_ sender: NSMenuItem) { handleToggle(sender, key: .twoFingerDoubleTap) }

    private enum ShortcutKey { case cmdW, cmdQ, cmdM, cmdH, cmdSpace, gestures, swipeLeft, swipeRight, swipeDown, swipeUp, twoFingerDoubleTap }

    private func handleToggle(_ sender: NSMenuItem, key: ShortcutKey) {
        guard let viewModel = viewModel else { return }
        switch key {
        case .cmdW: viewModel.isCmdWEnabled.toggle(); sender.state = viewModel.isCmdWEnabled ? .on : .off
        case .cmdQ: viewModel.isCmdQEnabled.toggle(); sender.state = viewModel.isCmdQEnabled ? .on : .off
        case .cmdM: viewModel.isCmdMEnabled.toggle(); sender.state = viewModel.isCmdMEnabled ? .on : .off
        case .cmdH: viewModel.isCmdHEnabled.toggle(); sender.state = viewModel.isCmdHEnabled ? .on : .off
        case .cmdSpace: viewModel.isCmdSpaceEnabled.toggle(); sender.state = viewModel.isCmdSpaceEnabled ? .on : .off
        case .gestures: viewModel.isGesturesEnabled.toggle(); sender.state = viewModel.isGesturesEnabled ? .on : .off
        case .swipeLeft: viewModel.isSwipeLeftEnabled.toggle(); sender.state = viewModel.isSwipeLeftEnabled ? .on : .off
        case .swipeRight: viewModel.isSwipeRightEnabled.toggle(); sender.state = viewModel.isSwipeRightEnabled ? .on : .off
        case .swipeDown: viewModel.isSwipeDownEnabled.toggle(); sender.state = viewModel.isSwipeDownEnabled ? .on : .off
        case .swipeUp: viewModel.isSwipeUpEnabled.toggle(); sender.state = viewModel.isSwipeUpEnabled ? .on : .off
        case .twoFingerDoubleTap: viewModel.isTwoFingerDoubleTapEnabled.toggle(); sender.state = viewModel.isTwoFingerDoubleTapEnabled ? .on : .off
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        guard let viewModel = viewModel else { return }
        viewModel.toggleLaunchAtLogin()
        sender.state = viewModel.isLaunchAtLoginEnabled ? .on : .off
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
        
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
