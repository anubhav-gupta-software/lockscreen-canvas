import Foundation

/// Where paired canvases are stored.
///
/// Leave the placeholder in place and the app stays in local mode: drawings
/// are saved on this iPhone and, when the App Group is enabled, on its widgets.
/// Replace `placeholderDatabaseURL` with the root of a Firebase Realtime
/// Database (or paste that URL into Settings) to sync between two phones.
/// No Firebase SDK and no API key are required; the database rules are the
/// access control. See the README.
enum SyncConfig {
    static let placeholderDatabaseURL = "https://YOUR_PROJECT-default-rtdb.firebaseio.com"

    /// `override` comes from Settings. An empty override uses the compiled URL.
    static func databaseURL(override: String) -> URL? {
        let typed = override.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = typed.isEmpty ? placeholderDatabaseURL : typed
        guard !candidate.contains("YOUR_PROJECT"),
              let url = URL(string: candidate),
              url.scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return normalizeRoot(url)
    }

    static func normalizeRoot(_ url: URL) -> URL {
        var string = url.absoluteString
        while string.hasSuffix("/") {
            string.removeLast()
        }
        if string.hasSuffix(".json") {
            string.removeLast(5)
        }
        return URL(string: string) ?? url
    }
}
