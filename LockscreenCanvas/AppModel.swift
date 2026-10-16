import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profile: LocalProfile
    @Published private(set) var session: SharedSession?
    @Published private(set) var document: CanvasDocument
    @Published private(set) var isBusy = false
    @Published var lastError: String?
    @Published private(set) var remoteTick = 0

    private let store: SharedStore
    private var pushTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var editGeneration = 0
    private var isDirty = false
    private var isPushing = false

    init(store: SharedStore = SharedStore()) {
        self.store = store
        let loadedProfile = store.loadProfile()
        profile = loadedProfile
        let loadedSession = store.loadSession()
        session = loadedSession
        if let loadedSession, let saved = store.loadDocument(), saved.code == loadedSession.code {
            document = saved
        } else if let loadedSession {
            document = CanvasDocument.empty(code: loadedSession.code)
        } else {
            document = CanvasDocument.empty(code: "")
        }
    }

    var displayName: String {
        let trimmed = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Friend" : trimmed
    }

    var isRemoteSync: Bool {
        SyncConfig.databaseURL(override: profile.remoteURL) != nil
    }

    var statusLine: String {
        let partner = document.partnerLine(excluding: profile.deviceID)
        if isRemoteSync {
            return partner
        }
        return "On this iPhone only · \(partner)"
    }

    var shareMessage: String {
        let code = InviteCode.formatted(session?.code ?? document.code)
        return "Draw with me on Doodl. Code: \(code)"
    }

    func updateDisplayName(_ name: String) {
        profile.displayName = String(name.prefix(40))
        store.save(profile)
        guard session != nil else { return }
        var next = document
        next.upsertPartner(deviceID: profile.deviceID, name: displayName)
        applyLocal(next)
    }

    /// Empty clears the override and returns to whatever is compiled into SyncConfig.
    func updateRemoteURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, SyncConfig.databaseURL(override: trimmed) == nil {
            return "Use an https link, like https://your-project-default-rtdb.firebaseio.com"
        }
        profile.remoteURL = trimmed
        store.save(profile)
        if session != nil {
            isDirty = true
            schedulePush()
        }
        return nil
    }

    func createCanvas() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let code = InviteCode.generate()
        var created = CanvasDocument.empty(code: code)
        created.upsertPartner(deviceID: profile.deviceID, name: displayName)
        document = created
        session = SharedSession(code: code, joinedAt: Date())
        isDirty = false
        store.save(session: session)
        store.save(document: document)
        WidgetReloader.reload()
        lastError = nil
        startPolling()
        if makeTransport() != nil {
            isDirty = true
            await push()
        }
    }

    func join(rawCode: String) async {
        let code = InviteCode.normalize(rawCode)
        guard InviteCode.isValid(code) else {
            lastError = "Enter the 6-character code."
            return
        }
        guard let transport = makeTransport() else {
            lastError = "Add a database URL in Settings to join a Doodl on another phone."
            return
        }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let claimed = try await claim(code: code, transport: transport)
            document = claimed
            session = SharedSession(code: code, joinedAt: Date())
            isDirty = false
            store.save(session: session)
            store.save(document: document)
            WidgetReloader.reload()
            lastError = nil
            remoteTick += 1
            startPolling()
        } catch {
            lastError = message(for: error)
        }
    }

    func leave() {
        pushTask?.cancel()
        stopPolling()
        session = nil
        document = CanvasDocument.empty(code: "")
        isDirty = false
        lastError = nil
        store.save(session: nil)
        store.save(document: nil)
        WidgetReloader.reload()
    }

    func applyLocal(_ updated: CanvasDocument) {
        guard let code = session?.code else { return }
        var next = updated
        next.code = code
        if next.partners.first(where: { $0.deviceID == profile.deviceID })?.name != displayName {
            next.upsertPartner(deviceID: profile.deviceID, name: displayName)
        }
        if sameContent(next, document) {
            return
        }
        next.updatedAt = Date()
        document = next
        editGeneration += 1
        isDirty = true
        store.save(document: document)
        WidgetReloader.reload()
        schedulePush()
    }

    func flush() async {
        pushTask?.cancel()
        guard isDirty else { return }
        await push()
    }

    func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard session != nil else { return }
            startPolling()
            Task { await refresh() }
        case .background:
            Task { await flush() }
            stopPolling()
        default:
            break
        }
    }

    private func claim(code: String, transport: RESTTransport) async throws -> CanvasDocument {
        let snapshot = try await transport.fetch(code: code)
        guard var remote = snapshot.document else {
            throw SyncError.notFound
        }
        remote.upsertPartner(deviceID: profile.deviceID, name: displayName)
        do {
            try await transport.save(remote, ifMatch: snapshot.etag)
            return remote
        } catch SyncError.conflict {
            let latest = try await transport.fetch(code: code)
            guard var again = latest.document else { throw SyncError.notFound }
            again.upsertPartner(deviceID: profile.deviceID, name: displayName)
            try await transport.save(again, ifMatch: latest.etag)
            return again
        }
    }

    private func refresh() async {
        guard let code = session?.code, let transport = makeTransport() else { return }
        if isDirty || isPushing {
            await push()
            return
        }
        do {
            let snapshot = try await transport.fetch(code: code)
            guard let remote = snapshot.document else { return }
            let merged = document.merged(with: remote)
            guard merged != document else {
                lastError = nil
                return
            }
            document = merged
            store.save(document: document)
            lastError = nil
            remoteTick += 1
            WidgetReloader.reload()
        } catch {
            lastError = message(for: error)
        }
    }

    private func push() async {
        guard let code = session?.code, let transport = makeTransport() else {
            isDirty = false
            return
        }
        if isPushing {
            schedulePush()
            return
        }
        isPushing = true
        defer { isPushing = false }
        do {
            let payload = try await writeMerged(code: code, transport: transport)
            document = document.merged(with: payload)
            let stillDirty = !sameContent(document, payload)
            isDirty = stillDirty
            store.save(document: document)
            lastError = nil
            remoteTick += 1
            WidgetReloader.reload()
            if stillDirty {
                schedulePush()
            }
        } catch {
            lastError = message(for: error)
            store.save(document: document)
        }
    }

    private func writeMerged(code: String, transport: RESTTransport) async throws -> CanvasDocument {
        let snapshot = try await transport.fetch(code: code)
        var payload = document
        if let remote = snapshot.document {
            payload = document.merged(with: remote)
        }
        payload.code = code
        payload.updatedAt = Date()
        payload.upsertPartner(deviceID: profile.deviceID, name: displayName)
        do {
            try await transport.save(payload, ifMatch: snapshot.etag)
            return payload
        } catch SyncError.conflict {
            let latest = try await transport.fetch(code: code)
            payload = document
            if let remote = latest.document {
                payload = document.merged(with: remote)
            }
            payload.code = code
            payload.updatedAt = Date()
            payload.upsertPartner(deviceID: profile.deviceID, name: displayName)
            try await transport.save(payload, ifMatch: latest.etag)
            return payload
        }
    }

    private func schedulePush() {
        guard makeTransport() != nil else {
            isDirty = false
            return
        }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func makeTransport() -> RESTTransport? {
        guard let url = SyncConfig.databaseURL(override: profile.remoteURL) else { return nil }
        return RESTTransport(root: url)
    }

    private func sameContent(_ lhs: CanvasDocument, _ rhs: CanvasDocument) -> Bool {
        lhs.code == rhs.code
            && lhs.strokes == rhs.strokes
            && lhs.texts == rhs.texts
            && lhs.partners == rhs.partners
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
