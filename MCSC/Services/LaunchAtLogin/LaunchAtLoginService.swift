import Foundation
import ServiceManagement
import os

/// Wraps `SMAppService` to register/unregister MCSC as a login item.
/// Backs the "Launch at Login" menu item; reads the current status from the
/// system rather than keeping local state so the menu always reflects reality.
final class LaunchAtLoginService {
    private let service = SMAppService.mainApp

    /// `true` when MCSC is currently configured to launch at login.
    var isEnabled: Bool {
        return service.status == .enabled
    }

    /// Flips the launch-at-login registration: registers when disabled and
    /// unregisters when enabled.
    func toggle() {
        if isEnabled {
            unregister()
        } else {
            register()
        }
    }

    private func register() {
        do {
            try service.register()
        } catch {
            AppLogger.app.error("Failed to register launch service: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func unregister() {
        service.unregister { error in
            if let error = error {
                AppLogger.app.error("Failed to unregister launch service: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
