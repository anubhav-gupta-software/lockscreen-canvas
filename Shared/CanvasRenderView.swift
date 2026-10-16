import SwiftUI

struct CanvasRenderView: View {
    var document: CanvasDocument
    var liveStroke: Stroke?
    var monochrome = false

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            for stroke in document.visibleStrokes {
                draw(stroke, in: rect, context: &context)
            }
            if let liveStroke {
                draw(liveStroke, in: rect, context: &context)
            }
        }
        .overlay {
            GeometryReader { geo in
                ForEach(document.visibleTexts) { item in
                    Text(item.text)
                        .font(.system(size: max(9, item.fontSize * min(geo.size.width, geo.size.height)), weight: .medium, design: .serif))
                        .foregroundStyle(ink(item.colorHex))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: geo.size.width * 0.72)
                        .position(x: item.x * geo.size.width, y: item.y * geo.size.height)
                }
            }
            .allowsHitTesting(false)
        }
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        if document.visibleStrokes.isEmpty && document.visibleTexts.isEmpty {
            return "Empty Doodl"
        }
        return "Doodl with \(document.visibleStrokes.count) marks"
    }

    private func ink(_ hex: String) -> Color {
        monochrome ? .primary : Color(hex: hex)
    }

    private func draw(_ stroke: Stroke, in rect: CGRect, context: inout GraphicsContext) {
        let side = min(rect.width, rect.height)
        let lineWidth = max(1, stroke.width * side)
        let color = GraphicsContext.Shading.color(ink(stroke.colorHex))
        if stroke.points.count <= 1, let only = stroke.points.first {
            let center = map(only, in: rect)
            let dot = CGRect(
                x: center.x - lineWidth / 2,
                y: center.y - lineWidth / 2,
                width: lineWidth,
                height: lineWidth
            )
            context.fill(Path(ellipseIn: dot), with: color)
            return
        }
        context.stroke(
            smoothPath(stroke.points, in: rect),
            with: color,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func smoothPath(_ points: [StrokePoint], in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: map(first, in: rect))
        if points.count == 2 {
            path.addLine(to: map(points[1], in: rect))
            return path
        }
        for index in 1..<(points.count - 1) {
            let current = map(points[index], in: rect)
            let next = map(points[index + 1], in: rect)
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        if let last = points.last {
            path.addLine(to: map(last, in: rect))
        }
        return path
    }

    private func map(_ point: StrokePoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(point.x) * rect.width,
            y: rect.minY + CGFloat(point.y) * rect.height
        )
    }
}
