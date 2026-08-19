import Foundation

enum MovementPrompts {
    static func line(
        playerName: String,
        helperName: String,
        familyPlayMode: FamilyPlayMode,
        styleIndex: Int = 0
    ) -> String {
        let player = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let helper = helperName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "helper" : helperName

        let soloLines = [
            "Hop three times before you scan!",
            "Tip-toe to the next card!",
            "Spin around once — now hunt!",
            "Put the phone in your pocket and crawl!",
            "Take three big steps and scan!",
            "Reach up high, then scan down low!"
        ]

        let familyLines = [
            "Hop three times together!",
            "\(helper) and \(player), tip-toe to the next card!",
            "Everyone spin once — now hunt!",
            "\(helper), point — \(player), scan!",
            "Team crawl to the next spot!"
        ]

        switch familyPlayMode {
        case .solo, .withGrownUp:
            return soloLines[styleIndex % soloLines.count]
        case .withLittleHelper, .wholeFamily:
            let useFamily = styleIndex.isMultiple(of: 2)
            if useFamily {
                return familyLines[(styleIndex / 2) % familyLines.count]
            }
            return soloLines[styleIndex % soloLines.count]
        }
    }
}
