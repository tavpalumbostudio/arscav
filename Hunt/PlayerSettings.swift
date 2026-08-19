import Foundation

enum PlayerSettings {
    private static let nameKey = "arscav.playerName"
    private static let grownUpNameKey = "arscav.grownUpName"
    private static let helperNameKey = "arscav.helperName"
    private static let familyPlayModeKey = "arscav.familyPlayMode"
    private static let movementPromptsKey = "arscav.movementPromptsEnabled"
    private static let targetsPerRoundKey = "arscav.targetsPerRound"
    private static let shuffleTargetsKey = "arscav.shuffleTargets"
    private static let defaultName = "Cosmo"

    static func loadName() -> String {
        loadTrimmed(nameKey, default: defaultName)
    }

    static func saveName(_ raw: String) {
        saveTrimmed(raw, key: nameKey, default: defaultName)
    }

    static func loadGrownUpName() -> String {
        UserDefaults.standard.string(forKey: grownUpNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func saveGrownUpName(_ raw: String) {
        UserDefaults.standard.set(raw.trimmingCharacters(in: .whitespacesAndNewlines), forKey: grownUpNameKey)
    }

    static func loadHelperName() -> String {
        UserDefaults.standard.string(forKey: helperNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func saveHelperName(_ raw: String) {
        UserDefaults.standard.set(raw.trimmingCharacters(in: .whitespacesAndNewlines), forKey: helperNameKey)
    }

    static func loadFamilyPlayMode() -> FamilyPlayMode {
        guard let raw = UserDefaults.standard.string(forKey: familyPlayModeKey),
              let mode = FamilyPlayMode(rawValue: raw) else {
            return .solo
        }
        return mode
    }

    static func saveFamilyPlayMode(_ mode: FamilyPlayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: familyPlayModeKey)
    }

    static func loadMovementPromptsEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: movementPromptsKey)
    }

    static func saveMovementPromptsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: movementPromptsKey)
    }

    static func loadTargetsPerRound() -> Int {
        let stored = UserDefaults.standard.integer(forKey: targetsPerRoundKey)
        return stored == 0 ? 4 : min(max(stored, 1), 4)
    }

    static func saveTargetsPerRound(_ count: Int) {
        UserDefaults.standard.set(min(max(count, 1), 4), forKey: targetsPerRoundKey)
    }

    static func loadShuffleTargets() -> Bool {
        if UserDefaults.standard.object(forKey: shuffleTargetsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: shuffleTargetsKey)
    }

    static func saveShuffleTargets(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: shuffleTargetsKey)
    }

    private static func loadTrimmed(_ key: String, default defaultValue: String) -> String {
        let stored = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultValue : stored
    }

    private static func saveTrimmed(_ raw: String, key: String, default defaultValue: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed.isEmpty ? defaultValue : trimmed, forKey: key)
    }
}

enum PromptPersonalizer {
    static func personalize(_ line: String, name: String, chance: Double = 0.35) -> String {
        let player = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !player.isEmpty, Double.random(in: 0..<1) < chance else { return line }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return line }

        let lower = trimmed.lowercased()
        if lower.hasPrefix(player.lowercased()) { return trimmed }

        if lower.contains("you found") || lower.contains("you spotted") || lower.hasPrefix("nice") {
            let prefixes = ["Nice one, \(player)!", "Way to go, \(player)!", "Awesome, \(player)!"]
            return "\(prefixes.randomElement() ?? "Nice one, \(player)!") \(trimmed)"
        }

        if lower.hasPrefix("find ") || lower.hasPrefix("track ") || lower.contains("find the") || lower.contains("track the") {
            return "\(player), \(trimmed)"
        }

        if lower.hasPrefix("round time") || lower.contains("hunt the") || lower.contains("you are a") {
            return "\(player)! \(trimmed)"
        }

        return "\(player), \(trimmed)"
    }
}
