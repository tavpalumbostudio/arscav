import Foundation

enum IdleChatterKind: CaseIterable {
    case silly
    case fact
    case hint
    case wonder
    case coop
    case movement
}

enum IdleChatter {
    static func line(
        playerName: String,
        target: HuntObject,
        round: HuntRound,
        familyPlayMode: FamilyPlayMode,
        movementPromptsEnabled: Bool,
        grownUpName: String,
        helperName: String,
        styleIndex: Int = 0
    ) -> String {
        let kind = pickKind(
            styleIndex: styleIndex,
            familyPlayMode: familyPlayMode,
            movementPromptsEnabled: movementPromptsEnabled
        )
        switch kind {
        case .silly:
            return sillyLine(playerName: playerName, target: target, round: round, styleIndex: styleIndex)
        case .fact:
            return factLine(playerName: playerName, target: target, round: round, styleIndex: styleIndex)
        case .hint:
            return hintLine(playerName: playerName, target: target, styleIndex: styleIndex)
        case .wonder:
            return WonderLines.line(
                playerName: playerName,
                target: target,
                round: round,
                styleIndex: styleIndex
            )
        case .coop:
            let context = PromptContext(
                playerName: playerName,
                familyPlayMode: familyPlayMode,
                grownUpName: grownUpName,
                helperName: helperName,
                sessionTargetIDs: [],
                foundIDs: [],
                round: round
            )
            return CoopPrompts.line(moment: .idle, context: context, styleIndex: styleIndex)
                ?? sillyLine(playerName: playerName, target: target, round: round, styleIndex: styleIndex)
        case .movement:
            return MovementPrompts.line(
                playerName: playerName,
                helperName: helperName,
                familyPlayMode: familyPlayMode,
                styleIndex: styleIndex
            )
        }
    }

    private static func pickKind(
        styleIndex: Int,
        familyPlayMode: FamilyPlayMode,
        movementPromptsEnabled: Bool
    ) -> IdleChatterKind {
        let roll = (styleIndex * 7 + Int.random(in: 0...99)) % 100
        if familyPlayMode != .solo, roll < 20 { return .coop }
        if movementPromptsEnabled, roll >= 20, roll < 35 { return .movement }
        if roll < 55 { return .silly }
        if roll < 70 { return .wonder }
        if roll < 85 { return .fact }
        return .hint
    }

    private static func sillyLine(
        playerName: String,
        target: HuntObject,
        round: HuntRound,
        styleIndex: Int
    ) -> String {
        let name = target.name
        let templates: [String]
        if round.isPredatorHunt {
            let prey = name
            templates = [
                "The \(prey) is being sneaky!",
                "Your prey is hiding like a ninja!",
                "Track that \(prey) — don't give up!",
                "Somewhere out there, a \(prey) is face-down on a card.",
                "Keep scanning — predators never quit!"
            ]
        } else {
            templates = [
                "The \(name) is playing hide and seek!",
                "Somewhere a \(name) card is waiting for you.",
                "Keep scanning — you're doing great!",
                "The \(name) won't find itself!",
                "I bet the \(name) is being super sneaky.",
                "Wave the camera around like a magic wand!"
            ]
        }
        let base = templates[styleIndex % templates.count]
        return PromptPersonalizer.personalize(base, name: playerName, chance: 0.45)
    }

    private static func factLine(
        playerName: String,
        target: HuntObject,
        round: HuntRound,
        styleIndex: Int
    ) -> String {
        let name = target.name
        let category = round.title
        let templates: [String]
        if round.isPredatorHunt {
            templates = [
                "Fun fact: \(category) hunters have excellent eyesight!",
                "Did you know? Tracking prey takes patience.",
                "In the wild, spotting a \(name) takes sharp eyes!",
                "Predators can be very quiet when they hunt."
            ]
        } else {
            templates = [
                "Did you know? \(name.capitalized)s are part of the \(category) hunt!",
                "Fun fact: \(category) hunts are full of surprises.",
                "Here's a tip: the \(name) might be on any marker!",
                "Cool fact: every card has a number on the back.",
                "Did you know? Some cards are decoys — pick wisely!"
            ]
        }
        let base = templates[styleIndex % templates.count]
        return PromptPersonalizer.personalize(base, name: playerName, chance: 0.35)
    }

    private static func hintLine(
        playerName: String,
        target: HuntObject,
        styleIndex: Int
    ) -> String {
        guard let number = target.markerNumber else {
            return PromptPersonalizer.personalize(
                "Keep looking — check every marker number!",
                name: playerName,
                chance: 0.35
            )
        }
        return MarkerHintProvider.hint(
            for: number,
            styleIndex: styleIndex,
            playerName: playerName
        )
    }
}
