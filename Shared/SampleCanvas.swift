import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum SampleCanvas {
    /// A small heart used for the widget gallery and the welcome screen.
    static func preview() -> CanvasDocument {
        var document = CanvasDocument.empty(code: "SAMPLE", at: Date(timeIntervalSince1970: 0))
        document.strokes = [
            Stroke(
                id: UUID(uuidString: "7C1A6B3E-4F20-4A11-9C55-0A1B2C3D4E5F") ?? UUID(),
                points: heartPoints(),
                colorHex: "C6452C",
                width: 0.02,
                createdAt: Date(timeIntervalSince1970: 0),
                revision: 1,
                isDeleted: false
            )
        ]
        document.texts = [
            TextItem(
                id: UUID(uuidString: "91B2C4D6-E8F0-4123-A456-7890ABCDEF12") ?? UUID(),
                text: "hi",
                x: 0.5,
                y: 0.8,
                colorHex: "1A1714",
                fontSize: 0.09,
                createdAt: Date(timeIntervalSince1970: 1),
                revision: 1,
                isDeleted: false
            )
        ]
        document.partners = [
            Partner(deviceID: "sample", name: "Sam", updatedAt: Date(timeIntervalSince1970: 1))
        ]
        return document
    }

    private static func heartPoints() -> [StrokePoint] {
        var points: [StrokePoint] = []
        let steps = 90
        for index in 0...steps {
            let t = Double(index) / Double(steps) * .pi * 2
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            // The curve's y grows upward; the page's y grows downward.
            let nx = (x + 18) / 36
            let ny = (14 - y) / 36
            points.append(StrokePoint.clamped(nx * 0.62 + 0.19, ny * 0.56 + 0.16))
        }
        return points
    }
}
