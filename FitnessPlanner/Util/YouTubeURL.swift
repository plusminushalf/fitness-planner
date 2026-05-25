import Foundation

enum YouTubeURL {
    /// Extracts a YouTube video ID from common URL forms:
    /// - youtu.be/{id}
    /// - youtube.com/watch?v={id}
    /// - youtube.com/embed/{id}
    /// - youtube.com/shorts/{id}
    /// (also accepts www. and m. subdomains, and youtube-nocookie.com)
    static func videoID(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let host = url.host?.lowercased()
        else { return nil }

        let normalizedHost = host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "m.", with: "")

        switch normalizedHost {
        case "youtu.be":
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : firstSegment(path)
        case "youtube.com", "youtube-nocookie.com":
            let path = url.path
            if path == "/watch" || path.hasPrefix("/watch") {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
                   !v.isEmpty {
                    return v
                }
            }
            if path.hasPrefix("/embed/") {
                return firstSegment(String(path.dropFirst("/embed/".count)))
            }
            if path.hasPrefix("/shorts/") {
                return firstSegment(String(path.dropFirst("/shorts/".count)))
            }
            if path.hasPrefix("/v/") {
                return firstSegment(String(path.dropFirst("/v/".count)))
            }
            return nil
        default:
            return nil
        }
    }

    private static func firstSegment(_ s: String) -> String? {
        let segment = s.split(separator: "/").first.map(String.init) ?? s
        return segment.isEmpty ? nil : segment
    }
}
