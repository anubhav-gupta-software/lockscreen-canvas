import Foundation

// Standalone checks for the drawing model and sync helpers.
// Compile with the Foundation sources in Shared/, then run. Not part of the app target.

@main
enum CheckCanvas {
    static func main() {
        checkInviteCode()
        checkSyncConfig()
        checkMerge()
        checkUndoRedo()
        checkEraseAndClear()
        checkText()
        checkJSONAndStore()
        checkSample()
        print("all canvas checks passed")
    }

    static func checkInviteCode() {
        var generator = SplitGenerator(values: [0, 1, 2, 3, 4, 5])
        let code = InviteCode.generate(using: &generator)
        expect(code.count == 6, "code length")
        expect(InviteCode.isValid(code), "generated code is valid")
        expect(InviteCode.normalize(" ab-c23 4 ") == "ABC234", "normalize strips junk")
        expect(InviteCode.formatted("ABC123") == "ABC-123", "format")
        expect(!InviteCode.isValid("ABC12"), "short codes fail")
        expect(!InviteCode.isValid("ABC12I"), "ambiguous letter is rejected")
    }

    static func checkSyncConfig() {
        expect(SyncConfig.databaseURL(override: "") == nil, "placeholder stays local")
        expect(SyncConfig.databaseURL(override: "http://example.com") == nil, "https only")
        let url = SyncConfig.databaseURL(override: "https://canvas-default-rtdb.firebaseio.com/")
        expect(url?.absoluteString == "https://canvas-default-rtdb.firebaseio.com", "trim slash")
    }

    static func checkMerge() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var mine = CanvasDocument.empty(code: "ABC123", at: now)
        var theirs = CanvasDocument.empty(code: "ABC123", at: now)
        var drawing = DrawingModel(document: mine)
        let added = drawing.addStroke(
            points: [StrokePoint(x: 0.1, y: 0.1), StrokePoint(x: 0.2, y: 0.2)],
            colorHex: "1A1714",
            width: 0.02,
            at: now
        )
        expect(added, "stroke added")
        mine = drawing.document

        var other = DrawingModel(document: theirs)
        _ = other.addStroke(
            points: [StrokePoint(x: 0.6, y: 0.6)],
            colorHex: "C6452C",
            width: 0.03,
            at: now.addingTimeInterval(5)
        )
        theirs = other.document

        let merged = mine.merged(with: theirs)
        expect(merged.visibleStrokes.count == 2, "merge keeps both strokes")

        var undone = drawing
        undone.undo(at: now.addingTimeInterval(10))
        let tombstone = undone.document.merged(with: theirs)
        let mineID = mine.visibleStrokes[0].id
        let mineStroke = tombstone.strokes.first { $0.id == mineID }
        expect(mineStroke?.isDeleted == true, "older copy does not revive an undo")
        expect(tombstone.visibleStrokes.count == 1, "partner stroke remains")
    }

    static func checkUndoRedo() {
        let now = Date(timeIntervalSince1970: 1_700_000_100)
        var drawing = DrawingModel(document: .empty(code: "ABC123", at: now))
        _ = drawing.addStroke(
            points: [StrokePoint(x: 0.2, y: 0.2)],
            colorHex: "1A1714",
            width: 0.01,
            at: now
        )
        expect(drawing.canUndo && !drawing.canRedo, "undo available")
        drawing.undo(at: now.addingTimeInterval(1))
        expect(drawing.document.visibleStrokes.isEmpty, "undo hides the stroke")
        expect(drawing.document.strokes.first?.revision == 2, "undo bumps revision")
        drawing.redo(at: now.addingTimeInterval(2))
        expect(drawing.document.visibleStrokes.count == 1, "redo restores the stroke")
        expect(drawing.document.visibleStrokes.first?.revision == 3, "redo bumps revision again")
        expect(drawing.document.visibleStrokes.first?.points.count == 1, "points come back")
    }

    static func checkEraseAndClear() {
        let now = Date(timeIntervalSince1970: 1_700_000_200)
        var drawing = DrawingModel(document: .empty(code: "ABC123", at: now))
        _ = drawing.addStroke(
            points: [StrokePoint(x: 0.1, y: 0.2), StrokePoint(x: 0.4, y: 0.2)],
            colorHex: "1A1714",
            width: 0.02,
            at: now
        )
        _ = drawing.addStroke(
            points: [StrokePoint(x: 0.8, y: 0.8)],
            colorHex: "2C5D8A",
            width: 0.02,
            at: now.addingTimeInterval(1)
        )
        drawing.beginErase()
        drawing.erase(at: StrokePoint(x: 0.25, y: 0.2), radius: 0.05)
        drawing.endErase(at: now.addingTimeInterval(2))
        expect(drawing.document.visibleStrokes.count == 1, "eraser removes one stroke")
        drawing.undo(at: now.addingTimeInterval(3))
        expect(drawing.document.visibleStrokes.count == 2, "undo restores the erased stroke")

        drawing.clear(at: now.addingTimeInterval(4))
        expect(drawing.document.visibleStrokes.isEmpty, "clear removes the page")
        drawing.undo(at: now.addingTimeInterval(5))
        expect(drawing.document.visibleStrokes.count == 2, "undo clear restores both")
    }

    static func checkText() {
        let now = Date(timeIntervalSince1970: 1_700_000_300)
        var drawing = DrawingModel(document: .empty(code: "ABC123", at: now))
        let point = StrokePoint(x: 0.5, y: 0.4)
        expect(
            drawing.addText("  hello\nthere ", at: point, colorHex: "1A1714", fontSize: 0.08, date: now),
            "text added"
        )
        expect(drawing.document.visibleTexts.first?.text == "hello there", "text is cleaned")
        let item = drawing.document.visibleTexts[0]
        expect(drawing.updateText(id: item.id, text: "hey", at: now.addingTimeInterval(1)), "text edited")
        drawing.undo(at: now.addingTimeInterval(2))
        expect(drawing.document.visibleTexts.first?.text == "hello there", "undo edit")
        drawing.moveText(id: item.id, to: StrokePoint(x: 0.2, y: 0.3))
        drawing.commitTextMove(id: item.id, before: item, at: now.addingTimeInterval(3))
        expect(drawing.document.visibleTexts.first?.x == 0.2, "text moved")
        let hit = drawing.document.text(near: StrokePoint(x: 0.2, y: 0.3))
        expect(hit?.id == item.id, "hit test finds the text")
    }

    static func checkJSONAndStore() {
        let now = Date(timeIntervalSince1970: 1_700_000_400)
        var document = CanvasDocument.empty(code: "ABC123", at: now)
        document.upsertPartner(deviceID: "device", name: "  Ada ", at: now)
        expect(document.partners.first?.name == "Ada", "name trimmed")
        expect(document.partnerLine(excluding: "device") == "Waiting for them", "no partner yet")
        document.upsertPartner(deviceID: "other", name: "Sam", at: now)
        expect(document.partnerLine(excluding: "device") == "With Sam", "partner line")

        let data = try! CanvasJSON.encode(document)
        let decoded = try! CanvasJSON.decode(CanvasDocument.self, from: data)
        expect(decoded.code == document.code, "json code")
        expect(decoded.partners.count == 2, "json partners")

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = SharedStore(directory: directory)
        let profile = store.loadProfile()
        expect(!profile.deviceID.isEmpty, "profile created")
        store.save(session: SharedSession(code: "ABC123", joinedAt: now))
        store.save(document: document)
        expect(store.loadSession()?.code == "ABC123", "session round trip")
        expect(store.loadDocument()?.code == "ABC123", "document round trip")
        store.save(session: nil)
        store.save(document: nil)
        expect(store.loadSession() == nil && store.loadDocument() == nil, "cleared")
    }

    static func checkSample() {
        let sample = SampleCanvas.preview()
        expect(sample.visibleStrokes.first?.points.count ?? 0 > 30, "heart has points")
        let inside = sample.visibleStrokes[0].points.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 }
        expect(inside, "heart stays on the page")
        let copy = sample.displayCopy(strokeLimit: 1, pointLimit: 12)
        expect(copy.visibleStrokes.first?.points.count ?? 99 <= 12, "widget copy decimates")
    }

    static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            fputs("failed: \(message)\n", stderr)
            exit(1)
        }
    }
}

struct SplitGenerator: RandomNumberGenerator {
    var values: [UInt64]
    var index = 0
    mutating func next() -> UInt64 {
        let value = values[index % values.count]
        index += 1
        return value
    }
}
