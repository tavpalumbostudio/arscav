import Foundation

enum CoopPrompts {
    enum Moment {
        case intro
        case idle
        case afterFind
        case roundComplete
    }

    static func line(
        moment: Moment,
        context: PromptContext,
        styleIndex: Int = 0
    ) -> String? {
        guard context.familyPlayMode != .solo else { return nil }

        switch context.familyPlayMode {
        case .solo:
            return nil
        case .withGrownUp:
            return grownUpLine(moment: moment, context: context, styleIndex: styleIndex)
        case .withLittleHelper:
            return helperLine(moment: moment, context: context, styleIndex: styleIndex)
        case .wholeFamily:
            return styleIndex.isMultiple(of: 2)
                ? grownUpLine(moment: moment, context: context, styleIndex: styleIndex / 2)
                : helperLine(moment: moment, context: context, styleIndex: styleIndex / 2)
        }
    }

    private static func grownUpLine(moment: Moment, context: PromptContext, styleIndex: Int) -> String {
        let grownUp = context.resolvedGrownUpName
        let player = context.playerName
        switch moment {
        case .intro:
            let lines = [
                "\(player), ask \(grownUp) to hide the cards around the room!",
                "Team up with \(grownUp) — they can give you clues!",
                "\(grownUp) can help you hunt. Ready?"
            ]
            return lines[styleIndex % lines.count]
        case .idle:
            let lines = [
                "\(grownUp), give a silly clue!",
                "Ask \(grownUp) if you're getting warmer!",
                "\(grownUp) can peek where cards might be."
            ]
            return lines[styleIndex % lines.count]
        case .afterFind:
            let lines = [
                "High-five \(grownUp)!",
                "Tell \(grownUp) what you found!",
                "\(grownUp) says great job!"
            ]
            return lines[styleIndex % lines.count]
        case .roundComplete:
            let lines = [
                "Tell \(grownUp) everything you found!",
                "Give \(grownUp) a big hug — hunt complete!"
            ]
            return lines[styleIndex % lines.count]
        }
    }

    private static func helperLine(moment: Moment, context: PromptContext, styleIndex: Int) -> String {
        let helper = context.resolvedHelperName
        let player = context.playerName
        switch moment {
        case .intro:
            let lines = [
                "\(helper) can point at cards while \(player) scans!",
                "Helper job time — \(helper) cheers, \(player) finds!",
                "\(helper), clap when \(player) finds one!"
            ]
            return lines[styleIndex % lines.count]
        case .idle:
            let lines = [
                "\(helper), point at a card!",
                "\(helper), clap three times!",
                "\(helper), hop once for luck!",
                "Helper job: look under something low!"
            ]
            return lines[styleIndex % lines.count]
        case .afterFind:
            let lines = [
                "\(helper), cheer for \(player)!",
                "Big cheer from \(helper)!",
                "\(helper), do a happy dance!"
            ]
            return lines[styleIndex % lines.count]
        case .roundComplete:
            let lines = [
                "Everyone cheer together!",
                "\(helper) and \(player) — team win!"
            ]
            return lines[styleIndex % lines.count]
        }
    }
}
