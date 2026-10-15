import Foundation

enum InviteCode {
    static let length = 6
    /// Ambiguous glyphs (0, O, 1, I) are left out so a code can be read aloud.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(using generator: inout some RandomNumberGenerator) -> String {
        String((0..<length).map { _ in
            alphabet[Int.random(in: 0..<alphabet.count, using: &generator)]
        })
    }

    static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    static func normalize(_ raw: String) -> String {
        let allowed = Set(alphabet)
        return String(raw.uppercased().filter { allowed.contains($0) })
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }

    /// "ABC123" → "ABC-123"
    static func formatted(_ code: String) -> String {
        guard code.count > 3 else { return code }
        let split = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<split])-\(code[split...])"
    }
}
