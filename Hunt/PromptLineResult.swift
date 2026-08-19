import Foundation

struct PromptLineResult {
    enum Source: String {
        case llm
        case cannedTimeout
        case cannedUnavailable
        case cannedSanitized
        case cannedEmpty
        case cannedExplicit
    }

    let text: String
    let source: Source
    let rawLLMOutput: String?
    let latencySeconds: Double?

    var devSummary: String {
        var lines = [text, "", "[\(source.rawValue)]"]
        if let latencySeconds {
            lines.append(String(format: "Latency: %.1fs", latencySeconds))
        }
        if let raw = rawLLMOutput, source != .llm, !raw.isEmpty {
            lines.append("Raw: \(raw.prefix(160))")
        }
        return lines.joined(separator: "\n")
    }
}
