import Foundation

/// Local drawing history. Deletions bump `revision` and leave a tombstone so
/// a partner's copy can merge without bringing the mark back.
struct DrawingModel: Equatable {
    private(set) var document: CanvasDocument
    private var undoStack: [HistoryEntry] = []
    private var redoStack: [HistoryEntry] = []
    private var eraseBuffer: [Stroke] = []

    init(document: CanvasDocument) {
        self.document = document
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isPageFull: Bool { document.visibleStrokes.count >= CanvasDocument.strokeLimit }

    mutating func addStroke(points: [StrokePoint], colorHex: String, width: Double, at date: Date = Date()) -> Bool {
        guard !points.isEmpty, !isPageFull else { return false }
        let stroke = Stroke(
            id: UUID(),
            points: points,
            colorHex: colorHex,
            width: width,
            createdAt: date,
            revision: 1,
            isDeleted: false
        )
        document.strokes.append(stroke)
        document.updatedAt = date
        push(.addStroke(stroke))
        return true
    }

    mutating func beginErase() {
        eraseBuffer = []
    }

    mutating func erase(at point: StrokePoint, radius: Double) {
        let hits = document.strokes.filter { stroke in
            !stroke.isDeleted
                && !eraseBuffer.contains(where: { $0.id == stroke.id })
                && Self.hits(stroke, point: point, radius: radius)
        }
        for stroke in hits {
            eraseBuffer.append(stroke)
            tombstoneStroke(stroke.id)
        }
    }

    mutating func endErase(at date: Date = Date()) {
        let removed = eraseBuffer
        eraseBuffer = []
        guard !removed.isEmpty else { return }
        document.updatedAt = date
        push(.removeStrokes(removed))
    }

    mutating func addText(_ text: String, at point: StrokePoint, colorHex: String, fontSize: Double, date: Date = Date()) -> Bool {
        let cleaned = Self.cleaned(text)
        guard !cleaned.isEmpty else { return false }
        guard document.visibleTexts.count < CanvasDocument.textLimit else { return false }
        let item = TextItem(
            id: UUID(),
            text: cleaned,
            x: point.x,
            y: point.y,
            colorHex: colorHex,
            fontSize: fontSize,
            createdAt: date,
            revision: 1,
            isDeleted: false
        )
        document.texts.append(item)
        document.updatedAt = date
        push(.addText(item))
        return true
    }

    mutating func updateText(id: UUID, text: String, at date: Date = Date()) -> Bool {
        guard let index = document.texts.firstIndex(where: { $0.id == id && !$0.isDeleted }) else { return false }
        let cleaned = Self.cleaned(text)
        guard !cleaned.isEmpty else { return false }
        let before = document.texts[index]
        guard before.text != cleaned else { return false }
        var after = before
        after.text = cleaned
        after.revision = before.revision + 1
        document.texts[index] = after
        document.updatedAt = date
        push(.updateText(before: before, after: after))
        return true
    }

    mutating func moveText(id: UUID, to point: StrokePoint) {
        guard let index = document.texts.firstIndex(where: { $0.id == id && !$0.isDeleted }) else { return }
        document.texts[index].x = StrokePoint.clamped(point.x, point.y).x
        document.texts[index].y = StrokePoint.clamped(point.x, point.y).y
    }

    mutating func commitTextMove(id: UUID, before: TextItem, at date: Date = Date()) {
        guard let index = document.texts.firstIndex(where: { $0.id == id }) else { return }
        var after = document.texts[index]
        guard before.x != after.x || before.y != after.y else { return }
        after.revision = max(before.revision, after.revision) + 1
        after.isDeleted = false
        document.texts[index] = after
        document.updatedAt = date
        push(.updateText(before: before, after: after))
    }

    mutating func deleteText(id: UUID, at date: Date = Date()) {
        guard let index = document.texts.firstIndex(where: { $0.id == id && !$0.isDeleted }) else { return }
        let before = document.texts[index]
        tombstoneText(id)
        document.updatedAt = date
        push(.removeText(before))
    }

    mutating func clear(at date: Date = Date()) {
        let strokes = document.visibleStrokes
        let texts = document.visibleTexts
        guard !strokes.isEmpty || !texts.isEmpty else { return }
        for stroke in strokes {
            tombstoneStroke(stroke.id)
        }
        for text in texts {
            tombstoneText(text.id)
        }
        document.updatedAt = date
        push(.clear(strokes: strokes, texts: texts))
    }

    mutating func undo(at date: Date = Date()) {
        guard let entry = undoStack.popLast() else { return }
        applyUndo(entry)
        redoStack.append(entry)
        document.updatedAt = date
    }

    mutating func redo(at date: Date = Date()) {
        guard let entry = redoStack.popLast() else { return }
        applyRedo(entry)
        undoStack.append(entry)
        document.updatedAt = date
    }

    /// Fold in a partner's copy without dropping local history.
    mutating func integrateRemote(_ remote: CanvasDocument) {
        document = document.merged(with: remote)
    }

    private mutating func push(_ entry: HistoryEntry) {
        undoStack.append(entry)
        if undoStack.count > 40 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        dropStaleTombstones()
    }

    private mutating func applyUndo(_ entry: HistoryEntry) {
        switch entry {
        case .addStroke(let stroke):
            tombstoneStroke(stroke.id)
        case .removeStrokes(let strokes):
            for stroke in strokes {
                restore(stroke)
            }
        case .addText(let item):
            tombstoneText(item.id)
        case .removeText(let item):
            restore(item)
        case .updateText(let before, _):
            write(before)
        case .clear(let strokes, let texts):
            for stroke in strokes {
                restore(stroke)
            }
            for text in texts {
                restore(text)
            }
        }
    }

    private mutating func applyRedo(_ entry: HistoryEntry) {
        switch entry {
        case .addStroke(let stroke):
            restore(stroke)
        case .removeStrokes(let strokes):
            for stroke in strokes {
                tombstoneStroke(stroke.id)
            }
        case .addText(let item):
            restore(item)
        case .removeText(let item):
            tombstoneText(item.id)
        case .updateText(_, let after):
            write(after)
        case .clear(let strokes, let texts):
            for stroke in strokes {
                tombstoneStroke(stroke.id)
            }
            for text in texts {
                tombstoneText(text.id)
            }
        }
    }

    private mutating func tombstoneStroke(_ id: UUID) {
        guard let index = document.strokes.firstIndex(where: { $0.id == id }) else { return }
        document.strokes[index].isDeleted = true
        document.strokes[index].points = []
        document.strokes[index].revision += 1
    }

    private mutating func tombstoneText(_ id: UUID) {
        guard let index = document.texts.firstIndex(where: { $0.id == id }) else { return }
        document.texts[index].isDeleted = true
        document.texts[index].text = ""
        document.texts[index].revision += 1
    }

    private mutating func restore(_ stroke: Stroke) {
        var copy = stroke
        copy.isDeleted = false
        if let index = document.strokes.firstIndex(where: { $0.id == stroke.id }) {
            copy.revision = document.strokes[index].revision + 1
            document.strokes[index] = copy
        } else {
            document.strokes.append(copy)
        }
    }

    private mutating func restore(_ item: TextItem) {
        var copy = item
        copy.isDeleted = false
        if let index = document.texts.firstIndex(where: { $0.id == item.id }) {
            copy.revision = document.texts[index].revision + 1
            document.texts[index] = copy
        } else {
            document.texts.append(copy)
        }
    }

    private mutating func write(_ item: TextItem) {
        var copy = item
        copy.isDeleted = false
        if let index = document.texts.firstIndex(where: { $0.id == item.id }) {
            copy.revision = max(item.revision, document.texts[index].revision + 1)
            document.texts[index] = copy
        } else {
            document.texts.append(copy)
        }
    }

    private mutating func dropStaleTombstones() {
        let deletedStrokes = document.strokes.filter(\.isDeleted)
        if deletedStrokes.count > 400 {
            let overflow = deletedStrokes.sorted { $0.createdAt < $1.createdAt }.prefix(deletedStrokes.count - 400)
            let ids = Set(overflow.map(\.id))
            document.strokes.removeAll { ids.contains($0.id) }
        }
        let deletedTexts = document.texts.filter(\.isDeleted)
        if deletedTexts.count > 120 {
            let overflow = deletedTexts.sorted { $0.createdAt < $1.createdAt }.prefix(deletedTexts.count - 120)
            let ids = Set(overflow.map(\.id))
            document.texts.removeAll { ids.contains($0.id) }
        }
    }

    private static func cleaned(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 {
            return trimmed
        }
        return String(trimmed.prefix(80))
    }

    static func hits(_ stroke: Stroke, point: StrokePoint, radius: Double) -> Bool {
        guard !stroke.points.isEmpty else { return false }
        var previous: StrokePoint?
        for sample in stroke.points {
            if distance(sample, point) <= radius {
                return true
            }
            if let previous, distanceToSegment(point, previous, sample) <= radius {
                return true
            }
            previous = sample
        }
        return false
    }

    private static func distance(_ a: StrokePoint, _ b: StrokePoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func distanceToSegment(_ point: StrokePoint, _ a: StrokePoint, _ b: StrokePoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            return distance(point, a)
        }
        let t = min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        return distance(point, StrokePoint(x: a.x + t * dx, y: a.y + t * dy))
    }
}

enum HistoryEntry: Equatable {
    case addStroke(Stroke)
    case removeStrokes([Stroke])
    case addText(TextItem)
    case removeText(TextItem)
    case updateText(before: TextItem, after: TextItem)
    case clear(strokes: [Stroke], texts: [TextItem])
}
