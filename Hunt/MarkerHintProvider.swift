import Foundation

enum MarkerHintProvider {
    private static let riddles: [Int: [String]] = [
        1: ["It's the loneliest number!", "Just the first marker!"],
        2: ["A pair!", "Like shoes — they come in twos."],
        3: ["Three little pigs!", "A triangle has this many sides."],
        4: ["Legs on a dog!", "Wheels on a car!"],
        5: ["Fingers on one hand!", "Starfish arms if you're lucky."],
        6: ["Sides on a dice!", "Half a dozen!"],
        7: ["Colors in a rainbow!", "Days in a week!"],
        8: ["Legs on a spider!", "Octopus arms!"],
        9: ["Three times three!", "Cloud nine!"],
        10: ["Fingers on both hands!", "A perfect ten!"],
        11: ["One more than ten!", "Soccer players on a team."],
        12: ["Eggs in a dozen!", "Months in a year!"],
        13: ["A baker's dozen minus one!", "Unlucky for some!"],
        14: ["A fortnight of days!", "Two weeks!"],
        15: ["Three fives!", "Minutes in a quarter hour."],
        16: ["Sweet sixteen!", "Two eights!"],
        18: ["Two nines!", "Legal voting age in lots of places."],
        20: ["Fingers and toes!", "Two tens!"],
        24: ["Two dozen!", "Hours in a day!"]
    ]

    static func hint(for markerNumber: Int, styleIndex: Int, playerName: String) -> String {
        let player = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let style = styleIndex % 4

        switch style {
        case 0:
            if let riddle = riddles[markerNumber]?.randomElement() {
                return prefix(player: player, text: riddle)
            }
            return prefix(player: player, text: mathHint(for: markerNumber))
        case 1:
            return prefix(player: player, text: mathHint(for: markerNumber))
        case 2:
            if let multiply = multiplicationHint(for: markerNumber) {
                return prefix(player: player, text: multiply)
            }
            return prefix(player: player, text: mathHint(for: markerNumber))
        default:
            if styleIndex > 6, Double.random(in: 0..<1) < 0.12 {
                return prefix(
                    player: player,
                    text: "Look for marker \(String(format: "%02d", markerNumber))."
                )
            }
            if let riddle = riddles[markerNumber]?.randomElement() {
                return prefix(player: player, text: riddle)
            }
            return prefix(player: player, text: mathHint(for: markerNumber))
        }
    }

    private static func prefix(player: String, text: String) -> String {
        let lead = ["Psst", "Hmm", "Hint", "Hey"].randomElement() ?? "Psst"
        if player.isEmpty {
            return "\(lead) — \(text)"
        }
        return "\(lead), \(player) — \(text)"
    }

    static func mathHint(for markerNumber: Int) -> String {
        guard markerNumber > 0 else { return "Keep scanning!" }

        if markerNumber == 1 {
            return "Try marker 1!"
        }

        let termCount = markerNumber <= 6 ? 2 : (Bool.random() ? 2 : 3)
        var remaining = markerNumber
        var terms: [Int] = []

        for index in 0..<termCount {
            let slotsLeft = termCount - index
            if slotsLeft == 1 {
                terms.append(remaining)
            } else {
                let maxPick = max(1, remaining - (slotsLeft - 1))
                let pick = Int.random(in: 1...maxPick)
                terms.append(pick)
                remaining -= pick
            }
        }

        let expression = terms.map(String.init).joined(separator: " + ")
        return "Try marker \(expression)!"
    }

    private static func multiplicationHint(for markerNumber: Int) -> String? {
        guard markerNumber > 1 else { return nil }
        for factor in 2...12 {
            if markerNumber % factor == 0 {
                let other = markerNumber / factor
                if other >= 2, other <= 12 {
                    return "\(factor) times \(other)!"
                }
            }
        }
        return nil
    }
}
