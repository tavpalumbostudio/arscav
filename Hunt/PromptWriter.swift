import Foundation

enum PromptKind: Sendable {
    case intro(targetName: String)
    case find(targetName: String)
    case findRephrase(targetName: String)
    case decoy(revealedName: String, targetName: String)
    case collected(targetName: String)
    case roundComplete
    case complete
}

enum LLMTestPrompt: String, CaseIterable, Identifiable {
    case intro
    case find
    case decoy
    case collected
    case roundComplete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .intro: "Intro"
        case .find: "Find"
        case .decoy: "Decoy"
        case .collected: "Collected"
        case .roundComplete: "Round complete"
        }
    }

    func promptKind(targetName: String, decoyName: String) -> PromptKind {
        switch self {
        case .intro: return .intro(targetName: targetName)
        case .find: return .find(targetName: targetName)
        case .decoy: return .decoy(revealedName: decoyName, targetName: targetName)
        case .collected: return .collected(targetName: targetName)
        case .roundComplete: return .roundComplete
        }
    }
}

enum CannedPrompts {
    static func line(for kind: PromptKind, round: HuntRound) -> String {
        if round.isPredatorHunt {
            return predatorLine(for: kind, round: round)
        }
        switch kind {
        case .intro(let target):
            return "Round time: \(round.title). Find the \(target)!"
        case .find(let target), .findRephrase(let target):
            return "Find the \(target)."
        case .decoy(let revealed, let target):
            return "That's the \(revealed). Keep looking for the \(target)."
        case .collected(let target):
            return "You found the \(target)!"
        case .roundComplete:
            return "You finished \(round.title)! Great job!"
        case .complete:
            return "Hunt complete! Check your found items."
        }
    }

    private static func predatorLine(for kind: PromptKind, round: HuntRound) -> String {
        let hunter = round.predatorName ?? "hunter"
        switch kind {
        case .intro(let prey):
            return "You are a \(hunter)! Hunt the \(prey)!"
        case .find(let prey), .findRephrase(let prey):
            return "Track the \(prey)!"
        case .decoy(let revealed, let prey):
            return "That \(revealed) is not your prey. Hunt the \(prey)!"
        case .collected(let prey):
            return "You spotted the \(prey)!"
        case .roundComplete:
            return "Great hunt! You found all your prey as a \(hunter)!"
        case .complete:
            return "Great hunting! You found all your prey."
        }
    }
}

struct PromptWriter {
    private let runner: LLMRunner

    init(runner: LLMRunner) {
        self.runner = runner
    }

    func line(
        for kind: PromptKind,
        context: PromptContext,
        options: PromptLineOptions = PromptLineOptions()
    ) async -> String {
        await lineWithMetadata(for: kind, context: context, options: options).text
    }

    func lineWithMetadata(
        for kind: PromptKind,
        context: PromptContext,
        options: PromptLineOptions = PromptLineOptions()
    ) async -> PromptLineResult {
        let round = context.round
        let canned = personalizeIfNeeded(
            CannedPrompts.line(for: kind, round: round),
            kind: kind,
            playerName: context.playerName
        )
        let instruction = instruction(for: kind, context: context, options: options)
        let timeout = Self.inferenceTimeout(short: options.useShortTimeout)
        let started = Date()

        do {
            let generated = try await runner.generate(instruction, timeout: timeout)
            let latency = Date().timeIntervalSince(started)
            let (cleaned, rejected) = sanitizeWithReason(generated, kind: kind)
            if rejected {
                return PromptLineResult(
                    text: canned,
                    source: .cannedSanitized,
                    rawLLMOutput: generated,
                    latencySeconds: latency
                )
            }
            if cleaned.isEmpty {
                return PromptLineResult(
                    text: canned,
                    source: .cannedEmpty,
                    rawLLMOutput: generated,
                    latencySeconds: latency
                )
            }
            return PromptLineResult(
                text: personalizeIfNeeded(cleaned, kind: kind, playerName: context.playerName),
                source: .llm,
                rawLLMOutput: generated,
                latencySeconds: latency
            )
        } catch LLMError.timedOut {
            let latency = Date().timeIntervalSince(started)
            return PromptLineResult(
                text: canned,
                source: .cannedTimeout,
                rawLLMOutput: nil,
                latencySeconds: latency
            )
        } catch {
            let latency = Date().timeIntervalSince(started)
            return PromptLineResult(
                text: canned,
                source: .cannedUnavailable,
                rawLLMOutput: nil,
                latencySeconds: latency
            )
        }
    }

    private static func inferenceTimeout(short: Bool) -> TimeInterval {
#if targetEnvironment(simulator)
        short ? 30 : 60
#else
        short ? 4 : 8
#endif
    }

    private func instruction(
        for kind: PromptKind,
        context: PromptContext,
        options: PromptLineOptions
    ) -> String {
        let round = context.round
        let playerName = context.playerName
        let playerHint = playerName.isEmpty
            ? ""
            : " You may address the player as \(playerName)."
        let familyHint = familyInstructionHint(context: context)
        let remaining = context.remainingTargetNames()
        let stillNeed = remaining.isEmpty ? "" : " Still need: \(remaining.joined(separator: ", "))."
        let progress = context.sessionTargetCount() > 0
            ? " That was \(context.collectedCount()) of \(context.sessionTargetCount()) for this hunt."
            : ""

        if round.isPredatorHunt {
            let hunter = round.predatorName ?? "predator"
            switch kind {
            case .intro(let prey):
                return "Write ONE short playful kid sentence: you are a \(hunter) hunting prey. Say to hunt the \(prey). No scary words. No quotes.\(playerHint)\(familyHint)"
            case .find(let prey):
                return "Write ONE short playful kid sentence telling a \(hunter) to track the \(prey). Must include \(prey). No quotes.\(playerHint)"
            case .findRephrase(let prey):
                let avoid = options.avoidPhrase.map { " Different from: \($0)." } ?? ""
                return "Write ONE new playful kid sentence telling a \(hunter) to track the \(prey). Must include \(prey). No quotes.\(avoid)\(playerHint)"
            case .decoy(let revealed, let prey):
                return "Write ONE short playful kid sentence: a \(hunter) saw a \(revealed) but needs the \(prey) instead. Mention both animals.\(stillNeed) No quotes.\(familyHint)"
            case .collected(let prey):
                return "Write ONE short playful cheer that the \(hunter) spotted the \(prey). Must include \(prey).\(progress) No quotes.\(playerHint)\(familyHint)"
            case .roundComplete:
                return "Write ONE short playful sentence celebrating finishing a \(hunter) round. No quotes.\(familyHint)"
            case .complete:
                return "Write ONE short playful sentence celebrating a \(hunter) who found all its prey. No quotes."
            }
        }

        switch kind {
        case .intro(let target):
            let countHint = context.sessionTargetCount() > 0
                ? " This hunt has \(context.sessionTargetCount()) things to find."
                : ""
            return "Write ONE short silly kid sentence starting a scavenger hunt round called \(round.title). You must say to find the \(target).\(countHint) No quotes.\(playerHint)\(familyHint)"
        case .find(let target):
            return "Write ONE short silly sentence telling the player to find the \(target) in a \(round.title) hunt. Must include the word \(target). No quotes.\(playerHint)"
        case .findRephrase(let target):
            let avoid = options.avoidPhrase.map { " Different from: \($0)." } ?? ""
            return "Write ONE new silly kid sentence telling \(playerName) to find the \(target) in the \(round.title) hunt. Must include \(target). No quotes.\(avoid)\(playerHint)"
        case .decoy(let revealed, let target):
            return "Write ONE short silly sentence: they flipped a \(revealed) but still need the \(target). Mention both names.\(stillNeed) No quotes.\(familyHint)"
        case .collected(let target):
            let teaser = remaining.isEmpty ? "" : " Remaining: \(remaining.joined(separator: ", "))."
            return "Write ONE short silly cheer that they found the \(target). Must include \(target).\(progress)\(teaser) No quotes.\(playerHint)\(familyHint)"
        case .roundComplete:
            return "Write ONE short silly sentence celebrating finishing the \(round.title) scavenger hunt round. No quotes.\(familyHint)"
        case .complete:
            return "Write ONE short silly sentence celebrating finishing a scavenger hunt. No quotes."
        }
    }

    private func familyInstructionHint(context: PromptContext) -> String {
        switch context.familyPlayMode {
        case .solo:
            return ""
        case .withGrownUp:
            return " You may mention \(context.resolvedGrownUpName) can cheer."
        case .withLittleHelper:
            return " You may tell the helper that wasn't the right card."
        case .wholeFamily:
            return " You may mention \(context.resolvedHelperName) and \(context.resolvedGrownUpName) can cheer."
        }
    }

    private func personalizeIfNeeded(_ line: String, kind: PromptKind, playerName: String) -> String {
        switch kind {
        case .intro, .find, .findRephrase, .collected:
            return PromptPersonalizer.personalize(line, name: playerName)
        case .decoy, .roundComplete, .complete:
            return line
        }
    }

    private func sanitizeWithReason(_ raw: String, kind: PromptKind) -> (String, Bool) {
        var text = stripChatMarkup(raw)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.lowercased().hasPrefix("assistant") {
            text = String(text.dropFirst("assistant".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let first = text.split(separator: ".").first {
            let sentence = String(first).trimmingCharacters(in: .whitespaces) + "."
            if sentence.count > 8, sentence.count < 180 {
                text = sentence
            }
        }

        if text.isEmpty {
            return ("", false)
        }

        let requiredNames: [String]
        switch kind {
        case .intro(let target), .find(let target), .findRephrase(let target), .collected(let target):
            requiredNames = [target]
        case .decoy(let revealed, let target):
            requiredNames = [revealed, target]
        case .roundComplete, .complete:
            requiredNames = []
        }

        for name in requiredNames where !matchesRequired(text, name: name) {
            return (text, true)
        }
        return (text, false)
    }

    private func matchesRequired(_ text: String, name: String) -> Bool {
        if text.range(of: name, options: .caseInsensitive) != nil { return true }
        let words = name.split(separator: " ").map(String.init).filter { $0.count > 2 }
        guard !words.isEmpty else { return false }
        return words.contains { text.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func stripChatMarkup(_ text: String) -> String {
        text.replacingOccurrences(
            of: "<\\|[^|]+\\|>",
            with: "",
            options: .regularExpression
        )
    }
}
