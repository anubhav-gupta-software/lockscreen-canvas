import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct RemoteSnapshot: Equatable {
    var document: CanvasDocument?
    var etag: String?
}

enum SyncError: LocalizedError, Equatable {
    case notFound
    case refused
    case badResponse
    case unreachable
    case conflict

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No canvas is using that code."
        case .refused:
            return "The database refused the update. Check that canvases can be read and written."
        case .badResponse:
            return "The database sent back something I couldn't read."
        case .unreachable:
            return "Couldn't reach the database. Your drawing is still saved on this iPhone."
        case .conflict:
            return "The canvas changed while it was saving."
        }
    }
}

/// Firebase Realtime Database over plain HTTPS. The path is `/canvases/{code}.json`.
struct RESTTransport: Sendable {
    var root: URL

    func fetch(code: String) async throws -> RemoteSnapshot {
        let request = try makeRequest(code: code, method: "GET")
        let (data, response) = try await send(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let etag = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Etag")
            ?? (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
        if status == 404 {
            return RemoteSnapshot(document: nil, etag: etag)
        }
        try validate(response)
        if Self.isNull(data) {
            return RemoteSnapshot(document: nil, etag: etag)
        }
        do {
            let document = try CanvasJSON.decode(CanvasDocument.self, from: data)
            return RemoteSnapshot(document: document, etag: etag)
        } catch {
            throw SyncError.badResponse
        }
    }

    func save(_ document: CanvasDocument, ifMatch etag: String?) async throws {
        var request = try makeRequest(code: document.code, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "if-match")
        }
        request.httpBody = try CanvasJSON.encode(document)
        let (_, response) = try await send(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 412 {
            throw SyncError.conflict
        }
        try validate(response)
    }

    private func makeRequest(code: String, method: String) throws -> URLRequest {
        let rootString = SyncConfig.normalizeRoot(root).absoluteString
        guard let url = URL(string: "\(rootString)/canvases/\(code).json") else {
            throw SyncError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("true", forHTTPHeaderField: "X-Firebase-ETag")
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw SyncError.unreachable
        }
    }

    private func validate(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 {
            throw SyncError.refused
        }
        guard (200..<300).contains(status) else {
            throw SyncError.badResponse
        }
    }

    private static func isNull(_ data: Data) -> Bool {
        let trimmed = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "null"
    }
}
