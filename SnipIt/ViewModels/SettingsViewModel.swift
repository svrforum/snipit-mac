import Foundation
import ServiceManagement

@Observable
final class SettingsViewModel {

    // MARK: - Dependencies

    private let storageService: StorageService

    // MARK: - State

    var settings: AppSettings

    // MARK: - Initialization

    init(storageService: StorageService) {
        self.storageService = storageService
        self.settings = (try? storageService.loadSettings()) ?? AppSettings()
    }

    // MARK: - Persistence

    func save() {
        try? storageService.saveSettings(settings)
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
        save()
    }
}
