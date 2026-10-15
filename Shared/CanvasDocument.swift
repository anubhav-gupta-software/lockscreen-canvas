import Foundation

struct StrokePoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double

    static func clamped(_ x: Double, _ y: Double) -> StrokePoint {
        StrokePoint(
            x: min(1, max(0, (x * 10_000).rounded() / 10_000)),
            y: min(1, max(0, (y * 10_000).rounded() / 10_000))
        )
    }
}

struct Stroke: Codable, Equatable, Identifiable {
    var id: UUID
    var points: [StrokePoint]
    var colorHex: String
    var width: Double
    var createdAt: Date
    var revision: Int
    var isDeleted: Bool
}

struct TextItem: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var x: Double
    var y: Double
    var colorHex: String
    var fontSize: Double
    var createdAt: Date
    var revision: Int
    var isDeleted: Bool
}

struct Partner: Codable, Equatable, Identifiable {
    var deviceID: String
    var name: String
    var updatedAt: Date

    var id: String { deviceID }
}

struct CanvasDocument: Codable, Equatable {
    var code: String
    var strokes: [Stroke]
    var texts: [TextItem]
    var partners: [Partner]
    var updatedAt: Date

    static let strokeLimit = 300
    static let textLimit = 80

    static func empty(code: String, at date: Date = Date()) -> CanvasDocument {
        CanvasDocument(code: code, strokes: [], texts: [], partners: [], updatedAt: date)
    }

    var visibleStrokes: [Stroke] {
        strokes.filter { !$0.isDeleted }
    }

    var visibleTexts: [TextItem] {
        texts.filter { !$0.isDeleted }
    }

    func partnerLine(excluding deviceID: String?) -> String {
        let names = partners
            .filter { $0.deviceID != deviceID }
            .map(\.name)
            .filter { !$0.isEmpty }
        if names.isEmpty {
            return "Waiting for them"
        }
        if names.count == 1 {
            return "With \(names[0])"
        }
        return "With \(names.prefix(2).joined(separator: " & "))"
    }

    mutating func upsertPartner(deviceID: String, name: String, at date: Date = Date()) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmed.isEmpty ? "Friend" : trimmed
        if let index = partners.firstIndex(where: { $0.deviceID == deviceID }) {
            guard partners[index].name != display else { return }
            partners[index].name = display
            partners[index].updatedAt = date
        } else {
            partners.append(Partner(deviceID: deviceID, name: display, updatedAt: date))
        }
    }

    /// Union of both copies. The higher revision of a stroke or text wins,
    /// so one person can undo without deleting the other's new marks.
    func merged(with other: CanvasDocument) -> CanvasDocument {
        var result = self
        result.code = code.isEmpty ? other.code : code
        result.strokes = Self.mergeByRevision(strokes, other.strokes)
        result.texts = Self.mergeByRevision(texts, other.texts)
        result.partners = Self.mergePartners(partners, other.partners)
        result.updatedAt = max(updatedAt, other.updatedAt)
        return result
    }

    /// A lighter copy for WidgetKit timelines. Tombstones stay so a later merge
    /// still knows which marks were erased.
    func displayCopy(strokeLimit: Int = 120, pointLimit: Int = 80) -> CanvasDocument {
        var copy = self
        let keptIDs = Set(visibleStrokes.suffix(strokeLimit).map(\.id))
        copy.strokes = strokes.compactMap { stroke in
            if stroke.isDeleted {
                var tombstone = stroke
                tombstone.points = []
                return tombstone
            }
            guard keptIDs.contains(stroke.id) else { return nil }
            var kept = stroke
            kept.points = Self.decimate(stroke.points, limit: pointLimit)
            return kept
        }
        let keptTextIDs = Set(visibleTexts.suffix(40).map(\.id))
        copy.texts = texts.filter { $0.isDeleted || keptTextIDs.contains($0.id) }
        return copy
    }

    func text(near point: StrokePoint, tolerance: Double = 0.08) -> TextItem? {
        visibleTexts.min { lhs, rhs in
            Self.distance(lhs, point) < Self.distance(rhs, point)
        }.flatMap { item in
            Self.distance(item, point) <= tolerance ? item : nil
        }
    }

    private static func distance(_ item: TextItem, _ point: StrokePoint) -> Double {
        let dx = item.x - point.x
        let dy = item.y - point.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func decimate(_ points: [StrokePoint], limit: Int) -> [StrokePoint] {
        guard points.count > limit, limit >= 2 else { return points }
        let stride = Double(points.count - 1) / Double(limit - 1)
        var reduced: [StrokePoint] = []
        for index in 0..<limit {
            let source = min(points.count - 1, Int((Double(index) * stride).rounded()))
            reduced.append(points[source])
        }
        return reduced
    }

    private static func mergeByRevision<T: Revisioned>(_ local: [T], _ remote: [T]) -> [T] {
        var map: [UUID: T] = [:]
        for item in local + remote {
            if let existing = map[item.id] {
                if item.revision > existing.revision {
                    map[item.id] = item
                }
            } else {
                map[item.id] = item
            }
        }
        return map.values.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func mergePartners(_ local: [Partner], _ remote: [Partner]) -> [Partner] {
        var map: [String: Partner] = [:]
        for partner in local + remote {
            if let existing = map[partner.deviceID] {
                if partner.updatedAt >= existing.updatedAt {
                    map[partner.deviceID] = partner
                }
            } else {
                map[partner.deviceID] = partner
            }
        }
        return map.values.sorted { $0.deviceID < $1.deviceID }
    }
}

protocol Revisioned: Identifiable where ID == UUID {
    var id: UUID { get }
    var createdAt: Date { get }
    var revision: Int { get }
}

extension Stroke: Revisioned {}
extension TextItem: Revisioned {}
