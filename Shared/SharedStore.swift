import Foundation

struct LocalProfile: Codable, Equatable {
    var deviceID: String
    var displayName: String
    var remoteURL: String

    static func make() -> LocalProfile {
        LocalProfile(deviceID: UUID().uuidString, displayName: "", remoteURL: "")
    }

    static let empty = LocalProfile(deviceID: "", displayName: "", remoteURL: "")
}

struct SharedSession: Codable, Equatable {
    var code: String
    var joinedAt: Date
}

/// Files the app and the widget both read. When the App Group is missing,
/// this writes into the app sandbox instead, which the widget cannot see.
struct SharedStore {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else if let container = AppGroup.containerURL {
            self.directory = container
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = support.appendingPathComponent("LockscreenCanvas", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// Widget-side store. Does not create a private sandbox full of empty files
    /// when the App Group entitlement is absent.
    static func widgetStore() -> SharedStore? {
        guard let container = AppGroup.containerURL else { return nil }
        return SharedStore(directory: container)
    }

    func loadProfile() -> LocalProfile {
        if let profile = read(LocalProfile.self, name: "profile.json") {
            return profile
        }
        let profile = LocalProfile.make()
        save(profile)
        return profile
    }

    func save(_ profile: LocalProfile) {
        write(profile, name: "profile.json")
    }

    func loadSession() -> SharedSession? {
        read(SharedSession.self, name: "session.json")
    }

    func save(session: SharedSession?) {
        if let session {
            write(session, name: "session.json")
        } else {
            remove("session.json")
        }
    }

    func loadDocument() -> CanvasDocument? {
        read(CanvasDocument.self, name: "canvas.json")
    }

    func save(document: CanvasDocument?) {
        if let document {
            write(document, name: "canvas.json")
        } else {
            remove("canvas.json")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? CanvasJSON.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, name: String) {
        let url = directory.appendingPathComponent(name)
        guard let data = try? CanvasJSON.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func remove(_ name: String) {
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }
}
