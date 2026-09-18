import Foundation

public enum Fuzzy {
    /// Case-insensitive subsequence match. `nil` if `query` is not a subsequence of `text`.
    /// Higher is better. Normalized roughly to 0...1.
    public static func score(query: String, text: String) -> Double? {
        if query.isEmpty { return 0 }
        let q = Array(query.lowercased())
        let original = Array(text)
        let t = Array(text.lowercased())
        guard !t.isEmpty else { return nil }

        var ti = 0
        var consecutive = 0
        var raw = 0.0

        for (qi, qc) in q.enumerated() {
            var found = false
            while ti < t.count {
                if t[ti] == qc {
                    var add = 1.0
                    if ti == 0 {
                        add += 8
                    } else {
                        let prev = original[ti - 1]
                        if !prev.isLetter && !prev.isNumber {
                            add += 4
                        } else if original[ti].isUppercase && prev.isLowercase {
                            add += 3
                        }
                    }
                    if consecutive > 0 {
                        add += Double(consecutive) * 3
                    }
                    if qi == 0 && ti == 0 {
                        add += 4
                    }
                    raw += add
                    consecutive += 1
                    found = true
                    ti += 1
                    break
                } else {
                    consecutive = 0
                    ti += 1
                }
            }
            if !found { return nil }
        }

        let lengthPenalty = Double(t.count) * 0.12 + 1
        let normalized = min(1.0, (raw / lengthPenalty) / (Double(q.count) * 8.0))
        return normalized
    }

    public static func bestScore(query: String, texts: [String]) -> Double? {
        var best: Double?
        for text in texts {
            if let s = score(query: query, text: text) {
                best = max(best ?? 0, s)
            }
        }
        return best
    }
}
