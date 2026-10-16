import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum SampleCanvas {
    /// The welcome card and the widget gallery. Two people holding hands,
    /// a handwritten "gn", and a vermilion heart. Same brush fractions the
    /// editor offers: medium 0.018 for the figures and the heart, fine 0.008
    /// for the writing.
    static func preview() -> CanvasDocument {
        var document = CanvasDocument.empty(code: "SAMPLE", at: Date(timeIntervalSince1970: 0))
        let ink = "1A1714"
        let vermilion = "C6452C"
        let medium = 0.018
        let fine = 0.008
        var strokes: [Stroke] = []
        var n = 1

        func add(_ points: [StrokePoint], _ color: String, _ width: Double) {
            let id = UUID(uuidString: String(format: "7C1A6B3E-4F20-4A11-9C55-%012X", n)) ?? UUID()
            n += 1
            strokes.append(
                Stroke(
                    id: id,
                    points: points,
                    colorHex: color,
                    width: width,
                    createdAt: Date(timeIntervalSince1970: 0),
                    revision: 1,
                    isDeleted: false
                )
            )
        }

        add(circle(0.30, 0.215, 0.064), ink, medium)
        add(circle(0.585, 0.198, 0.070), ink, medium)
        add([StrokePoint.clamped(0.278, 0.200)], ink, 0.012)
        add([StrokePoint.clamped(0.318, 0.198)], ink, 0.012)
        add([StrokePoint.clamped(0.560, 0.182)], ink, 0.012)
        add([StrokePoint.clamped(0.608, 0.180)], ink, 0.012)
        add(smile(0.30, 0.222, 0.064), ink, fine)
        add(smile(0.585, 0.206, 0.070), ink, fine)
        add(line((0.30, 0.279), (0.30, 0.50)), ink, medium)
        add(line((0.585, 0.268), (0.585, 0.488)), ink, medium)
        add(curve([(0.30, 0.355), (0.37, 0.395), (0.445, 0.428), (0.515, 0.398), (0.585, 0.348)]), ink, medium)
        add(line((0.30, 0.355), (0.155, 0.445)), ink, medium)
        add(curve([(0.585, 0.348), (0.68, 0.292), (0.745, 0.228), (0.785, 0.262)]), ink, medium)
        add(line((0.30, 0.50), (0.195, 0.685)), ink, medium)
        add(line((0.30, 0.50), (0.405, 0.685)), ink, medium)
        add(line((0.585, 0.488), (0.475, 0.685)), ink, medium)
        add(line((0.585, 0.488), (0.705, 0.685)), ink, medium)
        add(circle(0.24, 0.80, 0.052), ink, fine)
        add(curve([(0.286, 0.775), (0.300, 0.845), (0.275, 0.915), (0.210, 0.940), (0.165, 0.905)]), ink, fine)
        add(line((0.40, 0.87), (0.40, 0.725)), ink, fine)
        add(curve([(0.40, 0.745), (0.455, 0.705), (0.52, 0.715), (0.575, 0.76), (0.585, 0.82), (0.575, 0.875)]), ink, fine)
        add(heart(0.78, 0.79, 0.070), vermilion, medium)

        document.strokes = strokes
        document.partners = [
            Partner(deviceID: "sample", name: "Sam", updatedAt: Date(timeIntervalSince1970: 1))
        ]
        return document
    }

    private static func circle(_ cx: Double, _ cy: Double, _ r: Double, steps: Int = 48) -> [StrokePoint] {
        (0...steps).map { index in
            let angle = -Double.pi / 2 + Double(index) / Double(steps) * Double.pi * 2
            return StrokePoint.clamped(cx + cos(angle) * r, cy + sin(angle) * r)
        }
    }

    private static func line(_ a: (Double, Double), _ b: (Double, Double), steps: Int = 10) -> [StrokePoint] {
        (0...steps).map { index in
            let t = Double(index) / Double(steps)
            return StrokePoint.clamped(a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t)
        }
    }

    private static func smile(_ cx: Double, _ cy: Double, _ r: Double) -> [StrokePoint] {
        (0...15).map { index in
            let t = Double(index) / 15
            let angle = (28 + t * 124) * Double.pi / 180
            let radius = r * 0.40
            return StrokePoint.clamped(
                cx + cos(angle) * radius,
                cy + r * 0.10 + sin(angle) * radius * 0.82
            )
        }
    }

    /// Catmull-Rom through a handful of knots. The page renderer smooths again.
    private static func curve(_ raw: [(Double, Double)], samples: Int = 6) -> [StrokePoint] {
        guard raw.count >= 2 else {
            return raw.map { StrokePoint.clamped($0.0, $0.1) }
        }
        let pts = [raw[0]] + raw + [raw[raw.count - 1]]
        var out: [StrokePoint] = []
        for index in 1..<(pts.count - 2) {
            let p0 = pts[index - 1]
            let p1 = pts[index]
            let p2 = pts[index + 1]
            let p3 = pts[index + 2]
            for step in 0..<samples {
                let t = Double(step) / Double(samples)
                let t2 = t * t
                let t3 = t2 * t
                let x = 0.5 * (
                    (2 * p1.0)
                        + (-p0.0 + p2.0) * t
                        + (2 * p0.0 - 5 * p1.0 + 4 * p2.0 - p3.0) * t2
                        + (-p0.0 + 3 * p1.0 - 3 * p2.0 + p3.0) * t3
                )
                let y = 0.5 * (
                    (2 * p1.1)
                        + (-p0.1 + p2.1) * t
                        + (2 * p0.1 - 5 * p1.1 + 4 * p2.1 - p3.1) * t2
                        + (-p0.1 + 3 * p1.1 - 3 * p2.1 + p3.1) * t3
                )
                out.append(StrokePoint.clamped(x, y))
            }
        }
        if let last = raw.last {
            out.append(StrokePoint.clamped(last.0, last.1))
        }
        return out
    }

    private static func heart(_ cx: Double, _ cy: Double, _ scale: Double, steps: Int = 80) -> [StrokePoint] {
        (0...steps).map { index in
            let t = Double(index) / Double(steps) * Double.pi * 2
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return StrokePoint.clamped(cx + (x / 16) * scale, cy - (y / 17) * scale)
        }
    }
}
