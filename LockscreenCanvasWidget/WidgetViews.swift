import SwiftUI
import WidgetKit

struct CanvasWidgetView: View {
    var entry: CanvasEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
            .widgetURL(URL(string: "lockscreen-canvas://canvas"))
            .privacySensitive(false)
    }

    private var monochrome: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return renderingMode != .fullColor
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AccessoryWidgetBackground()
        default:
            Theme.paper
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        case .systemLarge:
            large
        default:
            small
        }
    }

    private var hasDrawing: Bool {
        guard let document = entry.document else { return false }
        return !document.visibleStrokes.isEmpty || !document.visibleTexts.isEmpty
    }

    @ViewBuilder
    private var drawing: some View {
        if let document = entry.document, hasDrawing {
            CanvasRenderView(document: document, monochrome: monochrome)
        } else {
            emptyMark
        }
    }

    private var inline: some View {
        Label(inlineTitle, systemImage: "paintbrush.pointed")
            .widgetAccentable()
    }

    private var inlineTitle: String {
        if !entry.sharingAvailable { return "Canvas" }
        if let text = entry.document?.visibleTexts.last?.text, !text.isEmpty {
            if text.count > 28 {
                return String(text.prefix(28)) + "…"
            }
            return text
        }
        return hasDrawing ? "Shared canvas" : "Canvas"
    }

    private var circular: some View {
        drawing
            .padding(6)
            .widgetAccentable(monochrome)
    }

    private var rectangular: some View {
        drawing
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .widgetAccentable(monochrome)
    }

    private var small: some View {
        drawing
            .padding(12)
    }

    private var medium: some View {
        HStack(spacing: 0) {
            drawing
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text("Shared canvas")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let updatedAt = entry.updatedAt, hasDrawing {
                    Text(updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawing
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(caption)
                Spacer()
                if let updatedAt = entry.updatedAt, hasDrawing {
                    Text(updatedAt, style: .relative)
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    private var caption: String {
        if !entry.sharingAvailable {
            return "Open the app to draw"
        }
        if !hasDrawing {
            return "Nothing here yet"
        }
        return entry.partnerLine
    }

    private var emptyMark: some View {
        VStack(spacing: 6) {
            Image(systemName: "paintbrush.pointed")
                .font(.title3)
            if family != .accessoryCircular {
                Text(emptyTitle)
                    .font(.system(.caption, design: .serif))
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(monochrome ? Color.primary : Theme.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetAccentable(monochrome)
    }

    private var emptyTitle: String {
        entry.sharingAvailable ? "Nothing yet" : "Sharing off"
    }
}
