import Foundation
import XCTest

/// Covers the two "outside Mission Control" toggles (Dock + Title Bar):
/// defaults are off, Restore Defaults keeps them off, and mutations persist.
final class ShortcutConfigurationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearStoredToggles()
    }

    override func tearDown() {
        // Other suites construct `ShortcutConfiguration()` expecting defaults;
        // never leak mutated toggle state into or out of these tests.
        clearStoredToggles()
        super.tearDown()
    }

    private func clearStoredToggles() {
        for entry in ShortcutConfiguration.toggleDefaults {
            UserDefaults.standard.removeObject(forKey: entry.key)
        }
    }

    func testOutsideMCTogglesDefaultToOff() {
        let config = ShortcutConfiguration()
        XCTAssertFalse(config.isDockActionsOutsideMCEnabled)
        XCTAssertFalse(config.isTitleBarActionsOutsideMCEnabled)
    }

    func testRestoreDefaultsKeepsOutsideMCTogglesOff() {
        var config = ShortcutConfiguration()
        config.isDockActionsOutsideMCEnabled = true
        config.isTitleBarActionsOutsideMCEnabled = true

        config.restoreDefaults()

        XCTAssertFalse(config.isDockActionsOutsideMCEnabled)
        XCTAssertFalse(config.isTitleBarActionsOutsideMCEnabled)
    }

    func testTitleBarTogglePersistsAndReloadsFromUserDefaults() {
        let titleBarKey = "mcsc.titleBarActionsOutsideMC.enabled"
        var config = ShortcutConfiguration()
        config.isTitleBarActionsOutsideMCEnabled = true

        XCTAssertTrue(UserDefaults.standard.bool(forKey: titleBarKey))
        XCTAssertTrue(ShortcutConfiguration().isTitleBarActionsOutsideMCEnabled)

        config.isTitleBarActionsOutsideMCEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: titleBarKey))
    }

    /// Guards the single-source-of-truth contract: every stored-property
    /// literal must match its `toggleDefaults` entry, so `restoreDefaults()`
    /// can never drift from what a fresh instance reports.
    func testFreshInstanceMatchesToggleDefaultsTable() {
        let config = ShortcutConfiguration()
        for entry in ShortcutConfiguration.toggleDefaults {
            XCTAssertEqual(config[keyPath: entry.keyPath], entry.defaultValue,
                           "Stored-property default drifted from toggleDefaults for key \(entry.key)")
        }
    }

    func testRestoreDefaultsMatchesToggleDefaultsTableForEveryToggle() {
        var config = ShortcutConfiguration()
        for entry in ShortcutConfiguration.toggleDefaults {
            config[keyPath: entry.keyPath] = !entry.defaultValue
        }

        config.restoreDefaults()

        for entry in ShortcutConfiguration.toggleDefaults {
            XCTAssertEqual(config[keyPath: entry.keyPath], entry.defaultValue,
                           "Restore Defaults did not reset key \(entry.key)")
        }
    }
}
