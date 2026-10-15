import Foundation

/// Shared container used by the app and the widget extension.
///
/// The App Group entitlement is only included in the Debug and Release
/// configurations (the "LockscreenCanvas Shared" scheme). A free Personal
/// Team cannot sign that entitlement, so the default scheme leaves it off
/// and `containerURL` stays nil. Callers fall back to the app sandbox.
enum AppGroup {
    static let identifier = "group.com.anubhavgupta.lockscreen-canvas"

    static var containerURL: URL? {
        #if canImport(Darwin)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        #else
        nil
        #endif
    }

    static var isAvailable: Bool {
        containerURL != nil
    }
}
