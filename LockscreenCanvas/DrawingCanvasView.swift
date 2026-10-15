import SwiftUI

struct DrawingCanvasView: View {
    var document: CanvasDocument
    var tool: EditorTool
    var colorHex: String
    var width: Double
    var canDraw: Bool
    var onStroke: ([StrokePoint]) -> Void
    var onEraseBegan: () -> Void
    var onErase: (StrokePoint, Double) -> Void
    var onEraseEnded: () -> Void
    var onTextTap: (StrokePoint, TextItem?) -> Void
    var onTextMoveChanged: (TextItem, StrokePoint) -> Void
    var onTextMoveEnded: (TextItem) -> Void

    @State private var livePoints: [StrokePoint] = []
    @State private var moving: TextItem?
    @State private var eraserPoint: StrokePoint?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            CanvasRenderView(document: document, liveStroke: liveStroke)
                .frame(width: side, height: side)
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
                        if tool == .eraser, let eraserPoint {
                            let diameter = max(22, width * side * 1.6)
                            Circle()
                                .stroke(Theme.ink.opacity(0.35), lineWidth: 1)
                                .frame(width: diameter, height: diameter)
                                .position(x: eraserPoint.x * side, y: eraserPoint.y * side)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                .contentShape(Rectangle())
                .gesture(drag(side: side))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityAddTraits(.allowsDirectInteraction)
        }
    }

    private var liveStroke: Stroke? {
        guard tool == .pen, !livePoints.isEmpty else { return nil }
        return Stroke(
            id: UUID(),
            points: livePoints,
            colorHex: colorHex,
            width: width,
            createdAt: Date(),
            revision: 0,
            isDeleted: false
        )
    }

    private func drag(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = normalize(value.location, side: side)
                switch tool {
                case .pen:
                    guard canDraw else { return }
                    if let last = livePoints.last, distance(last, point, side: side) < 1.4 {
                        return
                    }
                    livePoints.append(point)
                case .eraser:
                    if livePoints.isEmpty {
                        onEraseBegan()
                    }
                    livePoints = [point]
                    eraserPoint = point
                    let radius = max(22, width * side * 1.6) / side
                    onErase(point, radius)
                case .text:
                    let moved = CGFloat(value.translation.width * value.translation.width + value.translation.height * value.translation.height).squareRoot()
                    if moving == nil, moved > 8 {
                        let start = normalize(value.startLocation, side: side)
                        if let hit = document.text(near: start, tolerance: 0.09) {
                            moving = hit
                        }
                    }
                    if let moving {
                        onTextMoveChanged(moving, point)
                    }
                }
            }
            .onEnded { value in
                let point = normalize(value.location, side: side)
                let moved = CGFloat(value.translation.width * value.translation.width + value.translation.height * value.translation.height).squareRoot()
                switch tool {
                case .pen:
                    var points = livePoints
                    if points.isEmpty, canDraw {
                        points = [point]
                    }
                    if !points.isEmpty {
                        onStroke(points)
                    }
                case .eraser:
                    onEraseEnded()
                case .text:
                    if let moving, moved >= 8 {
                        onTextMoveEnded(moving)
                    } else if moved < 10 {
                        let start = normalize(value.startLocation, side: side)
                        onTextTap(start, document.text(near: start, tolerance: 0.09))
                    }
                }
                livePoints = []
                moving = nil
                eraserPoint = nil
            }
    }

    private func normalize(_ location: CGPoint, side: CGFloat) -> StrokePoint {
        guard side > 0 else { return StrokePoint(x: 0.5, y: 0.5) }
        return StrokePoint.clamped(location.x / side, location.y / side)
    }

    private func distance(_ a: StrokePoint, _ b: StrokePoint, side: CGFloat) -> CGFloat {
        let dx = CGFloat(a.x - b.x) * side
        let dy = CGFloat(a.y - b.y) * side
        return (dx * dx + dy * dy).squareRoot()
    }
}
