import ServiceManagement

class LaunchAtLoginService {
    private let service = SMAppService.mainApp
    
    var isEnabled: Bool {
        return service.status == .enabled
    }
    
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
            print("Failed to register launch service: \(error)")
        }
    }
    
    private func unregister() {
        service.unregister { error in
            if let error = error {
                print("Failed to unregister launch service: \(error)")
            }
        }
    }
}
