import Foundation

struct HuntManifest: Codable, Sendable {
    var physicalMarkerWidthMeters: Double
    var markerCount: Int?
    var rounds: [HuntRound]

    var resolvedMarkerCount: Int {
        markerCount ?? 12
    }
}

enum GameplayMode: String, Codable, Sendable {
    case standard
    case predator
}

enum FamilyPlayMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case solo
    case withGrownUp
    case withLittleHelper
    case wholeFamily

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solo: "Solo"
        case .withGrownUp: "With grown-up"
        case .withLittleHelper: "With little helper"
        case .wholeFamily: "Whole family"
        }
    }
}

struct PromptContext: Sendable {
    var playerName: String
    var familyPlayMode: FamilyPlayMode
    var grownUpName: String
    var helperName: String
    var sessionTargetIDs: [String]
    var foundIDs: Set<String>
    var round: HuntRound

    var resolvedGrownUpName: String {
        let trimmed = grownUpName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "grown-up" : trimmed
    }

    var resolvedHelperName: String {
        let trimmed = helperName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "helper" : trimmed
    }

    func remainingTargetNames() -> [String] {
        sessionTargetIDs
            .filter { !foundIDs.contains($0) }
            .compactMap { round.object(id: $0)?.name }
    }

    func collectedCount() -> Int {
        sessionTargetIDs.filter { foundIDs.contains($0) }.count
    }

    func sessionTargetCount() -> Int {
        sessionTargetIDs.count
    }
}

struct PromptLineOptions: Sendable {
    var avoidPhrase: String?
    var useShortTimeout = false
}

struct HuntRound: Codable, Identifiable, Sendable, Hashable {
    var id: String
    var title: String
    var targets: [String]
    var objects: [HuntObject]
    var gameplayMode: GameplayMode?
    var categoryGroup: String?
    var predatorName: String?
    var predatorEmoji: String?
    var searchCategory: String?
    var pixabayCategory: String?

    var isPredatorHunt: Bool {
        gameplayMode == .predator
    }

    func object(id: String) -> HuntObject? {
        objects.first { $0.id == id }
    }

    func object(markerId: String) -> HuntObject? {
        objects.first { $0.markerId == markerId }
    }

    func target(at index: Int) -> HuntObject? {
        guard targets.indices.contains(index) else { return nil }
        return object(id: targets[index])
    }

    var pickerEmoji: String {
        if isPredatorHunt, let predatorEmoji, !predatorEmoji.isEmpty {
            return predatorEmoji
        }
        if let first = target(at: 0) {
            return first.emoji
        }
        return objects.first?.emoji ?? "🎯"
    }

    var pickerSubtitle: String {
        if isPredatorHunt {
            let prey = targets.prefix(3).compactMap { object(id: $0)?.name }
            if prey.isEmpty {
                return "Track the prey"
            }
            return "Prey: \(prey.joined(separator: ", "))"
        }
        let names = targets.prefix(3).compactMap { object(id: $0)?.name }
        return names.joined(separator: ", ")
    }
}

struct HuntObject: Codable, Identifiable, Sendable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var markerId: String
    var searchQuery: String?
    var searchCategory: String?

    var displayName: String { name }
    var capsName: String { name.uppercased() }

    var resolvedQuery: String {
        if let searchQuery, !searchQuery.isEmpty { return searchQuery }
        return "\(name) photo"
    }

    var markerNumber: Int? {
        let prefix = "marker-"
        guard markerId.hasPrefix(prefix) else { return nil }
        return Int(markerId.dropFirst(prefix.count))
    }
}

enum RevealOutcome: Sendable {
    case collected
    case decoy
    case alreadyFound
    case alreadyRevealed
}

enum HuntPhase: Equatable {
    case loading
    case selecting
    case playing
    case complete
}

enum ModelLoadStatus: Equatable {
    case idle
    case loading
    case ready
    case unavailable
}

struct MarkerCardPresentation: Equatable {
    var markerId: String
    var objectId: String
    var isFlipped: Bool
    var isPreview = false
}
