import Foundation

enum ImageSearchConfig {
    /// Bump when image provider or selection logic changes (invalidates disk cache).
    static let cacheVersion = "api-v4"

    static var pixabayAPIKey: String? { cleaned(secrets["PixabayAPIKey"]) }
    static var pexelsAPIKey: String? { cleaned(secrets["PexelsAPIKey"]) }
    static var googleAPIKey: String? { cleaned(secrets["GoogleCustomSearchAPIKey"]) }
    static var googleSearchEngineID: String? { cleaned(secrets["GoogleCustomSearchEngineID"]) }

    static var usesPixabay: Bool { pixabayAPIKey != nil }
    static var usesPexels: Bool { pexelsAPIKey != nil }
    static var usesGoogle: Bool { googleAPIKey != nil && googleSearchEngineID != nil }

    static var hasConfiguredProvider: Bool {
        usesPixabay || usesPexels || usesGoogle
    }

    private static let secrets: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = plist as? [String: String]
        else { return [:] }
        return dict
    }()

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("YOUR_") else { return nil }
        return trimmed
    }
}
