import Foundation

enum CSVParser {
    enum ParsedRow {
        case sectionHeader(WorkoutSection)
        case data([String: String])
    }

    /// Parses CSV text into a stream of rows.
    /// Recognizes lines whose first non-whitespace token is `#`:
    ///   - `# warmup` / `# exercise(s)` / `# cooldown` switch the current section.
    ///   - Any other `#`-prefixed line is treated as a comment and dropped.
    /// All other lines are interpreted relative to the (lowercased) header row.
    static func parse(_ input: String) -> [ParsedRow] {
        let rows = parseRows(input)
        guard let headerRow = rows.first else { return [] }
        let keys = headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var out: [ParsedRow] = []
        for row in rows.dropFirst() {
            if row.count == 1 && row[0].isEmpty { continue } // blank line
            if let first = row.first {
                let trimmed = first.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#") {
                    if let section = parseSectionHeader(trimmed) {
                        out.append(.sectionHeader(section))
                    }
                    continue
                }
            }
            var dict: [String: String] = [:]
            for (i, key) in keys.enumerated() {
                dict[key] = i < row.count ? row[i] : ""
            }
            out.append(.data(dict))
        }
        return out
    }

    private static func parseSectionHeader(_ line: String) -> WorkoutSection? {
        let body = line.drop(while: { $0 == "#" })
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        switch body {
        case "warmup", "warm-up", "warm up": return .warmup
        case "exercise", "exercises", "workout", "main": return .exercise
        case "cooldown", "cool-down", "cool down": return .cooldown
        default: return nil
        }
    }

    /// Lower-level: tokenize CSV into an array of rows, each row an array of fields.
    static func parseRows(_ input: String) -> [[String]] {
        var content = Substring(input)
        if content.first == "\u{FEFF}" { content = content.dropFirst() }

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let c = content[i]
            if inQuotes {
                if c == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
                        field.append("\"")
                        i = content.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row.removeAll(keepingCapacity: true)
                    field = ""
                case "\r":
                    row.append(field)
                    rows.append(row)
                    row.removeAll(keepingCapacity: true)
                    field = ""
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\n" {
                        i = content.index(after: next)
                        continue
                    }
                default:
                    field.append(c)
                }
            }
            i = content.index(after: i)
        }

        // Flush trailing field/row (file may not end in newline)
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
