import SwiftUI
import WidgetKit

struct CanvasEntry: TimelineEntry {
    var date: Date
    var document: CanvasDocument?
    var sharingAvailable: Bool
    var partnerLine: String
    var updatedAt: Date?
}

struct CanvasProvider: TimelineProvider {
    func placeholder(in context: Context) -> CanvasEntry {
        let sample = SampleCanvas.preview()
        return CanvasEntry(
            date: Date(),
            document: sample,
            sharingAvailable: true,
            partnerLine: "With Sam",
            updatedAt: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CanvasEntry) -> Void) {
        let entry = loadLocal()
        let blank = entry.document == nil
            || (entry.document?.visibleStrokes.isEmpty == true && entry.document?.visibleTexts.isEmpty == true)
        if context.isPreview && blank {
            completion(placeholder(in: context))
        } else {
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CanvasEntry>) -> Void) {
        Task {
            let entry = await loadFresh()
            let next = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadLocal() -> CanvasEntry {
        guard let store = SharedStore.widgetStore() else {
            return CanvasEntry(date: Date(), document: nil, sharingAvailable: false, partnerLine: "", updatedAt: nil)
        }
        let profile = store.loadProfile()
        let document = store.loadDocument()?.displayCopy()
        return CanvasEntry(
            date: Date(),
            document: document,
            sharingAvailable: true,
            partnerLine: document?.partnerLine(excluding: profile.deviceID) ?? "Waiting for them",
            updatedAt: document?.updatedAt
        )
    }

    private func loadFresh() async -> CanvasEntry {
        guard let store = SharedStore.widgetStore() else {
            return CanvasEntry(date: Date(), document: nil, sharingAvailable: false, partnerLine: "", updatedAt: nil)
        }
        let profile = store.loadProfile()
        var document = store.loadDocument()
        if let code = store.loadSession()?.code,
           let root = SyncConfig.databaseURL(override: profile.remoteURL) {
            let transport = RESTTransport(root: root)
            if let remote = try? await transport.fetch(code: code).document {
                let merged = document?.merged(with: remote) ?? remote
                if merged != document {
                    document = merged
                    store.save(document: merged)
                }
            }
        }
        let display = document?.displayCopy()
        return CanvasEntry(
            date: Date(),
            document: display,
            sharingAvailable: true,
            partnerLine: document?.partnerLine(excluding: profile.deviceID) ?? "Waiting for them",
            updatedAt: document?.updatedAt
        )
    }
}

struct SharedCanvasWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.anubhavgupta.lockscreen-canvas", provider: CanvasProvider()) { entry in
            CanvasWidgetView(entry: entry)
        }
        .configurationDisplayName("Shared Canvas")
        .description("The drawing you share, on the Home Screen and the Lock Screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

@main
struct LockscreenCanvasWidgets: WidgetBundle {
    var body: some Widget {
        SharedCanvasWidget()
    }
}
