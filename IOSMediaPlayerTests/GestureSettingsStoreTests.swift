import XCTest
@testable import IOSMediaPlayer

@MainActor
final class GestureSettingsStoreTests: XCTestCase {
    private static let suiteName = "GestureSettingsStoreTests"

    var defaults: UserDefaults!
    var store: GestureSettingsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        store = GestureSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        store = nil
        defaults = nil
        super.tearDown()
    }

    func testDefaultValues() {
        XCTAssertTrue(store.isSwipeDownToExitEnabled, "Swipe down to exit should default to true")
        XCTAssertTrue(store.isVolumeGestureEnabled, "Volume gesture toggle should default to true")
        XCTAssertTrue(store.isBrightnessGestureEnabled, "Brightness gesture toggle should default to true")
        XCTAssertTrue(store.isSeekGestureEnabled, "Seek gesture toggle should default to true")
        XCTAssertTrue(store.isDoubleTapToSkipEnabled, "Double tap to skip toggle should default to true")
        XCTAssertTrue(store.isSingleTapToToggleControlsEnabled, "Single tap to toggle controls should default to true")

        // Crucial requirement: only allow vertical gestures for brightness and volume when swipe down to exit is off
        XCTAssertFalse(store.areVerticalGesturesAllowed, "Vertical gestures must not be allowed when swipe down to exit is true")
        XCTAssertFalse(store.effectiveVolumeGestureEnabled, "Effective volume gesture must be false when swipe down to exit is true")
        XCTAssertFalse(store.effectiveBrightnessGestureEnabled, "Effective brightness gesture must be false when swipe down to exit is true")
    }

    func testVerticalGesturesAllowedWhenSwipeDownToExitIsOff() {
        store.isSwipeDownToExitEnabled = false

        XCTAssertTrue(store.areVerticalGesturesAllowed)
        XCTAssertTrue(store.effectiveVolumeGestureEnabled)
        XCTAssertTrue(store.effectiveBrightnessGestureEnabled)
    }

    func testVerticalGesturesRespectIndividualTogglesWhenSwipeDownIsOff() {
        store.isSwipeDownToExitEnabled = false

        store.isVolumeGestureEnabled = false
        XCTAssertFalse(store.effectiveVolumeGestureEnabled)
        XCTAssertTrue(store.effectiveBrightnessGestureEnabled)

        store.isBrightnessGestureEnabled = false
        XCTAssertFalse(store.effectiveBrightnessGestureEnabled)
    }

    func testSwipeDownToExitOverridesIndividualVerticalToggles() {
        store.isSwipeDownToExitEnabled = false
        store.isVolumeGestureEnabled = true
        store.isBrightnessGestureEnabled = true
        XCTAssertTrue(store.effectiveVolumeGestureEnabled)
        XCTAssertTrue(store.effectiveBrightnessGestureEnabled)

        // Turn swipe down to exit back on
        store.isSwipeDownToExitEnabled = true
        XCTAssertFalse(store.effectiveVolumeGestureEnabled, "Enabling swipe down to exit must disallow vertical volume gesture")
        XCTAssertFalse(store.effectiveBrightnessGestureEnabled, "Enabling swipe down to exit must disallow vertical brightness gesture")
        XCTAssertFalse(store.areVerticalGesturesAllowed)
    }

    func testPersistenceAcrossReloads() {
        store.isSwipeDownToExitEnabled = false
        store.isSeekGestureEnabled = false
        store.isDoubleTapToSkipEnabled = false
        store.isSingleTapToToggleControlsEnabled = false

        let reloadedStore = GestureSettingsStore(defaults: defaults)
        XCTAssertFalse(reloadedStore.isSwipeDownToExitEnabled)
        XCTAssertFalse(reloadedStore.isSeekGestureEnabled)
        XCTAssertFalse(reloadedStore.isDoubleTapToSkipEnabled)
        XCTAssertFalse(reloadedStore.isSingleTapToToggleControlsEnabled)
        XCTAssertTrue(reloadedStore.isVolumeGestureEnabled)
        XCTAssertTrue(reloadedStore.isBrightnessGestureEnabled)
        XCTAssertTrue(reloadedStore.effectiveVolumeGestureEnabled)
        XCTAssertTrue(reloadedStore.effectiveBrightnessGestureEnabled)
    }

    func testResetToDefaults() {
        store.isSwipeDownToExitEnabled = false
        store.isVolumeGestureEnabled = false
        store.isBrightnessGestureEnabled = false
        store.isSeekGestureEnabled = false
        store.isDoubleTapToSkipEnabled = false
        store.isSingleTapToToggleControlsEnabled = false

        store.resetToDefaults()

        XCTAssertTrue(store.isSwipeDownToExitEnabled)
        XCTAssertTrue(store.isVolumeGestureEnabled)
        XCTAssertTrue(store.isBrightnessGestureEnabled)
        XCTAssertTrue(store.isSeekGestureEnabled)
        XCTAssertTrue(store.isDoubleTapToSkipEnabled)
        XCTAssertTrue(store.isSingleTapToToggleControlsEnabled)
        XCTAssertFalse(store.areVerticalGesturesAllowed)
    }
}
