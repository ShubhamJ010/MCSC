import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: ShortcutViewModel?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusBar()
        
        let eventTap = EventTapService()
        let accessibility = AccessibilityService()
        
        viewModel = ShortcutViewModel(eventTapService: eventTap, accessibilityService: accessibility)
        
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
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "command.circle", accessibilityDescription: "MCSC")
        }
        
        let menu = NSMenu()
        
        let cmdWItem = NSMenuItem(title: "Toggle Cmd + W", action: #selector(toggleCmdW), keyEquivalent: "w")
        cmdWItem.state = .on
        menu.addItem(cmdWItem)
        
        let cmdQItem = NSMenuItem(title: "Toggle Cmd + Q", action: #selector(toggleCmdQ), keyEquivalent: "q")
        cmdQItem.state = .on
        menu.addItem(cmdQItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MCSC", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "Q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleCmdW(_ sender: NSMenuItem) {
        guard let viewModel = viewModel else { return }
        viewModel.isCmdWEnabled.toggle()
        sender.state = viewModel.isCmdWEnabled ? .on : .off
    }
    
    @objc private func toggleCmdQ(_ sender: NSMenuItem) {
        guard let viewModel = viewModel else { return }
        viewModel.isCmdQEnabled.toggle()
        sender.state = viewModel.isCmdQEnabled ? .on : .off
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
    }
}
