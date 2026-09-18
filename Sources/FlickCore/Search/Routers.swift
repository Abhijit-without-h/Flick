import Foundation

public enum Calculator {
    public static func looksLikeMath(_ query: String) -> Bool {
        let t = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("=") { return t.count > 1 }
        let operators = CharacterSet(charactersIn: "+-*/")
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard t.rangeOfCharacter(from: allowed.inverted) == nil else { return false }
        return t.rangeOfCharacter(from: operators) != nil
    }

    public static func evaluate(_ query: String) -> String? {
        var t = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("=") {
            t = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard looksLikeMath("=" + t) || looksLikeMath(t) else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard t.rangeOfCharacter(from: allowed.inverted) == nil else { return nil }
        guard let value = MiniMath.eval(t) else { return nil }
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(value)
    }
}

/// Tiny + - * / () evaluator. Avoids NSExpression format-string exceptions.
enum MiniMath {
    static func eval(_ string: String) -> Double? {
        var i = string.startIndex
        func skip() {
            while i < string.endIndex, string[i] == " " { i = string.index(after: i) }
        }
        func parseNumber() -> Double? {
            skip()
            let start = i
            if i < string.endIndex, string[i] == "+" || string[i] == "-" {
                i = string.index(after: i)
            }
            while i < string.endIndex, string[i].isNumber || string[i] == "." {
                i = string.index(after: i)
            }
            guard start < i else { return nil }
            return Double(string[start..<i])
        }
        func parseFactor() -> Double? {
            skip()
            guard i < string.endIndex else { return nil }
            if string[i] == "(" {
                i = string.index(after: i)
                guard let v = parseExpr() else { return nil }
                skip()
                guard i < string.endIndex, string[i] == ")" else { return nil }
                i = string.index(after: i)
                return v
            }
            return parseNumber()
        }
        func parseTerm() -> Double? {
            guard var v = parseFactor() else { return nil }
            while true {
                skip()
                guard i < string.endIndex else { return v }
                let c = string[i]
                if c == "*" {
                    i = string.index(after: i)
                    guard let r = parseFactor() else { return nil }
                    v *= r
                } else if c == "/" {
                    i = string.index(after: i)
                    guard let r = parseFactor() else { return nil }
                    guard r != 0 else { return nil }
                    v /= r
                } else {
                    return v
                }
            }
        }
        func parseExpr() -> Double? {
            guard var v = parseTerm() else { return nil }
            while true {
                skip()
                guard i < string.endIndex else { return v }
                let c = string[i]
                if c == "+" {
                    i = string.index(after: i)
                    guard let r = parseTerm() else { return nil }
                    v += r
                } else if c == "-" {
                    i = string.index(after: i)
                    guard let r = parseTerm() else { return nil }
                    v -= r
                } else {
                    return v
                }
            }
        }
        guard let v = parseExpr() else { return nil }
        skip()
        guard i == string.endIndex else { return nil }
        return v
    }
}

public enum PathRouter {
    public static func looksLikePath(_ query: String) -> Bool {
        let t = query.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("/") || t.hasPrefix("~")
    }

    public static func expanded(_ query: String) -> String {
        let t = query.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("~") {
            return NSString(string: t).expandingTildeInPath
        }
        return t
    }
}

public enum URLRouter {
    public static func url(from query: String) -> URL? {
        let t = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") {
            return URL(string: t)
        }
        if t.contains(" ") { return nil }
        if t.contains(".") && !t.hasPrefix(".") {
            let hostish = t.split(separator: "/").first.map(String.init) ?? t
            if hostish.contains(".") && hostish.rangeOfCharacter(from: .letters) != nil {
                return URL(string: "https://\(t)")
            }
        }
        return nil
    }
}
