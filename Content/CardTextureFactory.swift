import CoreGraphics
import UIKit

enum CardTextureFactory {
    static let cardSize = CGSize(width: 768, height: 1024)

    struct HuntCardTheme {
        let base: UIColor
        let accent: UIColor
        let deep: UIColor
        let ink: UIColor

        static func forRound(index: Int, round: HuntRound) -> HuntCardTheme {
            let palettes: [(UIColor, UIColor, UIColor)] = [
                (rgb(0.18, 0.42, 0.78), rgb(0.96, 0.82, 0.28), rgb(0.08, 0.18, 0.42)), // animals blue/gold
                (rgb(0.16, 0.58, 0.40), rgb(0.92, 0.96, 0.55), rgb(0.05, 0.28, 0.18)), // green
                (rgb(0.52, 0.28, 0.72), rgb(0.98, 0.72, 0.92), rgb(0.24, 0.10, 0.38)), // purple
                (rgb(0.78, 0.34, 0.22), rgb(1.00, 0.84, 0.48), rgb(0.38, 0.12, 0.08)), // rust
                (rgb(0.12, 0.52, 0.62), rgb(0.72, 0.94, 0.98), rgb(0.04, 0.24, 0.32)), // teal
                (rgb(0.62, 0.18, 0.44), rgb(1.00, 0.78, 0.86), rgb(0.28, 0.06, 0.22)), // magenta
                (rgb(0.34, 0.38, 0.72), rgb(0.82, 0.86, 1.00), rgb(0.12, 0.14, 0.38)), // indigo
                (rgb(0.72, 0.52, 0.14), rgb(1.00, 0.94, 0.62), rgb(0.32, 0.22, 0.04)), // amber
                (rgb(0.20, 0.48, 0.48), rgb(0.78, 0.96, 0.88), rgb(0.06, 0.22, 0.22)), // seafoam
                (rgb(0.48, 0.22, 0.58), rgb(0.88, 0.70, 1.00), rgb(0.20, 0.08, 0.28)), // violet
                (rgb(0.82, 0.28, 0.36), rgb(1.00, 0.82, 0.72), rgb(0.34, 0.08, 0.12)), // coral
                (rgb(0.24, 0.34, 0.52), rgb(0.74, 0.84, 0.98), rgb(0.08, 0.12, 0.24)), // slate
            ]
            let paletteIndex = abs(index) % palettes.count
            let (base, accent, deep) = palettes[paletteIndex]
            if round.isPredatorHunt {
                return HuntCardTheme(
                    base: blend(base, deep, amount: 0.35),
                    accent: accent,
                    deep: deep,
                    ink: UIColor.white
                )
            }
            return HuntCardTheme(base: base, accent: accent, deep: deep, ink: UIColor.white)
        }

        private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
            UIColor(red: r, green: g, blue: b, alpha: 1)
        }

        private static func blend(_ a: UIColor, _ b: UIColor, amount: CGFloat) -> UIColor {
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
            b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            let t = min(max(amount, 0), 1)
            return UIColor(
                red: ar + (br - ar) * t,
                green: ag + (bg - ag) * t,
                blue: ab + (bb - ab) * t,
                alpha: 1
            )
        }
    }

    static func makeBack(markerNumber: Int, round: HuntRound, roundIndex: Int) -> UIImage {
        let theme = HuntCardTheme.forRound(index: roundIndex, round: round)
        let size = cardSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let numberLabel = String(format: "%02d", max(markerNumber, 0))
        let huntLabel = round.title.uppercased()

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [theme.base.cgColor, theme.deep.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width * 0.2, y: 0),
                end: CGPoint(x: size.width * 0.8, y: size.height),
                options: []
            )

            theme.accent.withAlphaComponent(0.14).setFill()
            for ring in stride(from: 120.0, through: 520.0, by: 80.0) {
                let ringRect = CGRect(
                    x: size.width / 2 - ring / 2,
                    y: size.height * 0.38 - ring / 2,
                    width: ring,
                    height: ring
                )
                UIBezierPath(ovalIn: ringRect).fill()
            }

            let frame = rect.insetBy(dx: 36, dy: 36)
            theme.accent.withAlphaComponent(0.95).setStroke()
            let outer = UIBezierPath(roundedRect: frame, cornerRadius: 40)
            outer.lineWidth = 10
            outer.stroke()

            theme.ink.withAlphaComponent(0.18).setStroke()
            let inner = UIBezierPath(roundedRect: frame.insetBy(dx: 18, dy: 18), cornerRadius: 30)
            inner.lineWidth = 3
            inner.stroke()

            let badgeDiameter: CGFloat = 360
            let badgeRect = CGRect(
                x: (size.width - badgeDiameter) / 2,
                y: size.height * 0.34 - badgeDiameter / 2,
                width: badgeDiameter,
                height: badgeDiameter
            )
            theme.deep.withAlphaComponent(0.55).setFill()
            UIBezierPath(ovalIn: badgeRect).fill()
            theme.accent.setStroke()
            let badgeRing = UIBezierPath(ovalIn: badgeRect.insetBy(dx: 6, dy: 6))
            badgeRing.lineWidth = 8
            badgeRing.stroke()

            let numberFont = roundedFont(size: 220, weight: .heavy)
            let numberAttrs: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: theme.ink
            ]
            drawCentered(numberLabel, in: badgeRect, attributes: numberAttrs)

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: theme.ink.withAlphaComponent(0.92),
                .kern: 4
            ]
            let titleRect = CGRect(x: 48, y: 88, width: size.width - 96, height: 48)
            drawCentered(huntLabel, in: titleRect, attributes: titleAttrs)

            if round.isPredatorHunt, let emoji = round.predatorEmoji {
                let emojiAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 52),
                    .foregroundColor: theme.ink
                ]
                let emojiRect = CGRect(x: 48, y: 140, width: size.width - 96, height: 64)
                drawCentered(emoji, in: emojiRect, attributes: emojiAttrs)
            }

            let hintAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                .foregroundColor: theme.ink.withAlphaComponent(0.88),
                .kern: 3
            ]
            let hintRect = CGRect(x: 48, y: size.height - 130, width: size.width - 96, height: 40)
            drawCentered("TAP TO FLIP", in: hintRect, attributes: hintAttrs)

            let slotAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium),
                .foregroundColor: theme.ink.withAlphaComponent(0.65)
            ]
            let slotRect = CGRect(x: 48, y: size.height - 88, width: size.width - 96, height: 32)
            drawCentered("MARKER \(numberLabel)", in: slotRect, attributes: slotAttrs)
        }
    }

    static func makeFace(image: UIImage?, name: String, emoji: String) -> UIImage {
        let size = cardSize
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            let captionHeight: CGFloat = 160
            let photoRect = CGRect(x: 36, y: 36, width: size.width - 72, height: size.height - captionHeight - 48)

            UIColor.white.setFill()
            UIBezierPath(roundedRect: photoRect, cornerRadius: 24).fill()

            if let image {
                let fitted = aspectFillRect(for: image.size, in: photoRect.insetBy(dx: 8, dy: 8))
                image.draw(in: fitted)
            } else {
                let emojiRect = photoRect.insetBy(dx: 40, dy: 80)
                let emojiAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 280),
                    .foregroundColor: UIColor.black
                ]
                let ns = emoji as NSString
                let es = ns.size(withAttributes: emojiAttrs)
                ns.draw(
                    at: CGPoint(
                        x: emojiRect.midX - es.width / 2,
                        y: emojiRect.midY - es.height / 2
                    ),
                    withAttributes: emojiAttrs
                )
            }

            let bar = CGRect(x: 0, y: size.height - captionHeight, width: size.width, height: captionHeight)
            UIColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(rect: bar).fill()

            let label = name.uppercased() as NSString
            let fontSize: CGFloat = name.count > 14 ? 36 : 48
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let textSize = label.size(withAttributes: attrs)
            label.draw(
                at: CGPoint(
                    x: max(20, (size.width - textSize.width) / 2),
                    y: bar.midY - textSize.height / 2
                ),
                withAttributes: attrs
            )
        }
    }

    static func makeHunterPortrait(image: UIImage?, name: String, emoji: String) -> UIImage {
        let size = CGSize(width: 280, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            let captionHeight: CGFloat = 72
            let photoRect = CGRect(x: 16, y: 16, width: size.width - 32, height: size.height - captionHeight - 24)

            UIColor.white.setFill()
            UIBezierPath(roundedRect: photoRect, cornerRadius: 16).fill()

            if let image {
                let fitted = aspectFillRect(for: image.size, in: photoRect.insetBy(dx: 4, dy: 4))
                image.draw(in: fitted)
            } else {
                let emojiAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 96),
                    .foregroundColor: UIColor.black
                ]
                let ns = emoji as NSString
                let es = ns.size(withAttributes: emojiAttrs)
                ns.draw(
                    at: CGPoint(x: photoRect.midX - es.width / 2, y: photoRect.midY - es.height / 2),
                    withAttributes: emojiAttrs
                )
            }

            let bar = CGRect(x: 0, y: size.height - captionHeight, width: size.width, height: captionHeight)
            UIColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(rect: bar).fill()

            let label = name.uppercased() as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let textSize = label.size(withAttributes: attrs)
            label.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: bar.midY - textSize.height / 2),
                withAttributes: attrs
            )
        }
    }

    static func silhouette() -> UIImage {
        let size = CGSize(width: 256, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(white: 0.85, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18).fill()
            UIColor(white: 0.72, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 28, y: 28, width: 200, height: 200), cornerRadius: 12).fill()
            UIBezierPath(roundedRect: CGRect(x: 40, y: 250, width: 176, height: 36), cornerRadius: 8).fill()
        }
    }

    private static func aspectFillRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: bounds.midX - w / 2,
            y: bounds.midY - h / 2,
            width: w,
            height: h
        )
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    private static func drawCentered(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let ns = text as NSString
        let size = ns.size(withAttributes: attributes)
        let origin = CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        ns.draw(at: origin, withAttributes: attributes)
    }
}
