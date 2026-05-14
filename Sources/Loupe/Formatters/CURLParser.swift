import Foundation

/// Parses a `curl` command string into a `URLRequest`-style description.
/// Handles the common flags: `-X / --request`, `-H / --header`,
/// `-d / --data / --data-raw / --data-binary`, `--url`, plus single- /
/// double-quoted arguments and `\` line continuations.
public enum CURLParser {

    public struct Parsed: Equatable {
        public var url:     String
        public var method:  String
        public var headers: [(key: String, value: String)]
        public var body:    String

        public static func == (a: Parsed, b: Parsed) -> Bool {
            a.url == b.url && a.method == b.method && a.body == b.body &&
            a.headers.elementsEqual(b.headers, by: { $0.key == $1.key && $0.value == $1.value })
        }
    }

    public static func parse(_ input: String) -> Parsed? {
        // Strip line continuations and tokenize shell-style.
        let cleaned = input.replacingOccurrences(of: "\\\n", with: " ")
                           .trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokenize(cleaned)
        guard !tokens.isEmpty else { return nil }

        var i = 0
        // Skip leading "curl" if present.
        if tokens[i].lowercased() == "curl" { i += 1 }

        var url:     String = ""
        var method:  String = ""
        var headers: [(String, String)] = []
        var body:    String = ""

        while i < tokens.count {
            let tok = tokens[i]
            switch tok {
            case "-X", "--request":
                i += 1
                if i < tokens.count { method = tokens[i].uppercased() }
            case "-H", "--header":
                i += 1
                if i < tokens.count {
                    let raw = tokens[i]
                    if let colon = raw.firstIndex(of: ":") {
                        let k = String(raw[..<colon]).trimmingCharacters(in: .whitespaces)
                        let v = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                        headers.append((k, v))
                    }
                }
            case "-d", "--data", "--data-raw", "--data-binary", "--data-urlencode":
                i += 1
                if i < tokens.count {
                    body = tokens[i]
                    if method.isEmpty { method = "POST" }
                }
            case "--url":
                i += 1
                if i < tokens.count { url = tokens[i] }
            case "-A", "--user-agent":
                i += 1
                if i < tokens.count { headers.append(("User-Agent", tokens[i])) }
            case "-e", "--referer":
                i += 1
                if i < tokens.count { headers.append(("Referer", tokens[i])) }
            case "-b", "--cookie":
                i += 1
                if i < tokens.count { headers.append(("Cookie", tokens[i])) }
            case "-I", "--head":
                method = "HEAD"
            case "-G", "--get":
                method = "GET"
            // Unsupported flags that take a value — skip both the flag and its arg.
            case "-u", "--user", "-o", "--output", "-K", "--config",
                 "--cacert", "--cert", "--key", "--proxy", "-x",
                 "--connect-timeout", "--max-time", "-m":
                i += 1
            // Boolean flags — skip just the flag.
            case "-L", "--location", "-k", "--insecure", "-s", "--silent",
                 "-v", "--verbose", "-i", "--include", "--compressed",
                 "-f", "--fail", "-n", "--netrc":
                break
            default:
                // First non-flag token is the URL.
                if url.isEmpty, !tok.hasPrefix("-") { url = tok }
            }
            i += 1
        }

        if method.isEmpty { method = "GET" }
        guard !url.isEmpty else { return nil }
        return Parsed(url: url, method: method, headers: headers, body: body)
    }

    // MARK: - Tokenizer

    /// Shell-style tokenization: respects single quotes (literal), double quotes
    /// (with backslash escapes), and backslash-escaped characters outside quotes.
    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escapeNext = false
        var hasToken = false

        for ch in input {
            if escapeNext {
                current.append(ch)
                escapeNext = false
                hasToken = true
                continue
            }
            if ch == "\\", !inSingle {
                escapeNext = true
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                hasToken = true
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                hasToken = true
                continue
            }
            if ch.isWhitespace, !inSingle, !inDouble {
                if hasToken {
                    tokens.append(current)
                    current = ""
                    hasToken = false
                }
                continue
            }
            current.append(ch)
            hasToken = true
        }
        if hasToken { tokens.append(current) }
        return tokens
    }
}
