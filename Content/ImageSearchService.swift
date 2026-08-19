import Foundation
import UIKit

enum ImageSearchService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.httpAdditionalHeaders = [
            "User-Agent": "ARScav/0.1 (iOS scavenger hunt; image search for educational cards)"
        ]
        return URLSession(configuration: config)
    }()

    static func fetchImage(for object: HuntObject, in round: HuntRound) async -> UIImage? {
        let context = SearchContext(
            objectName: object.name,
            cacheKey: object.id,
            categoryHint: object.searchCategory ?? round.searchCategory ?? round.title,
            categoryTitle: round.title,
            categoryId: round.id,
            pixabayCategory: round.pixabayCategory,
            baseQuery: object.resolvedQuery,
            refreshAttempt: 0
        )
        return await fetchImage(context: context)
    }

    /// Fetches another photo candidate (2nd, 3rd, … result) for the same card.
    static func refreshImage(for object: HuntObject, in round: HuntRound, attempt: Int) async -> UIImage? {
        let context = SearchContext(
            objectName: object.name,
            cacheKey: object.id,
            categoryHint: object.searchCategory ?? round.searchCategory ?? round.title,
            categoryTitle: round.title,
            categoryId: round.id,
            pixabayCategory: round.pixabayCategory,
            baseQuery: object.resolvedQuery,
            refreshAttempt: max(1, attempt)
        )
        return await fetchImage(context: context)
    }

    static func fetchImage(forName name: String, in round: HuntRound, cacheKey: String) async -> UIImage? {
        let hint = round.searchCategory ?? round.title
        let context = SearchContext(
            objectName: name,
            cacheKey: cacheKey,
            categoryHint: hint,
            categoryTitle: round.title,
            categoryId: round.id,
            pixabayCategory: round.pixabayCategory,
            baseQuery: "\(name) \(hint) photo",
            refreshAttempt: 0
        )
        return await fetchImage(context: context)
    }

    static func fetchImage(query: String, cacheKey: String) async -> UIImage? {
        let context = SearchContext(
            objectName: query,
            cacheKey: cacheKey,
            categoryHint: "",
            categoryTitle: "",
            categoryId: "",
            pixabayCategory: nil,
            baseQuery: query,
            refreshAttempt: 0
        )
        return await fetchImage(context: context)
    }

    private static func fetchImage(context: SearchContext) async -> UIImage? {
        let storageKey = context.storageKey
        if context.refreshAttempt == 0, let cached = await AssetCache.shared.uiImage(for: storageKey) {
            return cached
        }

        guard let remote = await searchRemoteImage(context: context) else { return nil }
        do {
            let (data, response) = try await session.data(from: remote)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else { return nil }
            if let jpeg = image.jpegData(compressionQuality: 0.86) {
                await AssetCache.shared.store(jpeg, for: storageKey)
            }
            return image
        } catch {
            return nil
        }
    }

    private static func searchRemoteImage(context: SearchContext) async -> URL? {
        var candidates: [ImageCandidate] = []
        var seenURLs = Set<String>()
        let pixabayPage = max(1, context.refreshAttempt)

        func consider(_ url: URL?, score: Int) {
            guard let url, score > 0 else { return }
            let key = url.absoluteString
            guard seenURLs.insert(key).inserted else { return }
            candidates.append(ImageCandidate(url: url, score: score))
        }

        // Pass 1: exact name searches (most reliable).
        for query in context.nameFirstQueries {
            if ImageSearchConfig.usesPixabay {
                for hit in await pixabayHits(query: query, category: context.pixabayCategory, page: pixabayPage) {
                    guard let url = hit.imageURL else { continue }
                    consider(url, score: scorePixabayHit(hit, context: context, strict: true))
                }
            }
            if context.refreshAttempt == 0, let url = await searchCommons(query: query) {
                consider(url, score: 950)
            }
        }

        if context.refreshAttempt == 0, let best = pickCandidate(from: candidates, attempt: 0), best.score >= 500 {
            return best.url
        }

        // Pass 2: name + short category hint.
        for query in context.contextQueries {
            if ImageSearchConfig.usesPixabay {
                for hit in await pixabayHits(query: query, category: context.pixabayCategory, page: pixabayPage) {
                    guard let url = hit.imageURL else { continue }
                    consider(url, score: scorePixabayHit(hit, context: context, strict: true))
                }
            }
            if ImageSearchConfig.usesPexels {
                for photo in await pexelsPhotos(query: query, page: pixabayPage) {
                    guard let url = photo.imageURL else { continue }
                    consider(url, score: scorePexelsPhoto(photo, context: context, strict: true))
                }
            }
        }

        if context.refreshAttempt == 0, let best = pickCandidate(from: candidates, attempt: 0), best.score >= 400 {
            return best.url
        }

        // Pass 3: Wikimedia for stubborn/obscure items.
        if context.refreshAttempt == 0 && (context.prefersWikiFirst || candidates.isEmpty) {
            for query in context.nameFirstQueries {
                if let url = await searchCommons(query: query) {
                    consider(url, score: 850)
                }
            }
        }

        return pickCandidate(from: candidates, attempt: context.refreshAttempt)?.url
    }

    private static func pickCandidate(from candidates: [ImageCandidate], attempt: Int) -> ImageCandidate? {
        let sorted = candidates.sorted { $0.score > $1.score }
        guard !sorted.isEmpty else { return nil }
        let index = min(max(attempt, 0), sorted.count - 1)
        return sorted[index]
    }

    private struct SearchContext {
        let objectName: String
        let cacheKey: String
        let categoryHint: String
        let categoryTitle: String
        let categoryId: String
        let pixabayCategory: String?
        let baseQuery: String
        let refreshAttempt: Int

        var storageKey: String {
            let base = "\(ImageSearchConfig.cacheVersion)-\(cacheKey)"
            guard refreshAttempt > 0 else { return base }
            return "\(base)-alt\(refreshAttempt)"
        }

        var prefersWikiFirst: Bool {
            let id = categoryId.lowercased()
            return id.contains("dinosaur")
                || id.contains("prehistoric")
                || id.contains("ice-age")
                || id.contains("volcano")
        }

        var nameFirstQueries: [String] {
            let name = normalizedName
            return [name, "\(name) animal"].uniqued()
        }

        var contextQueries: [String] {
            let name = normalizedName
            let hint = compactCategoryHint
            var variants: [String] = []
            if !hint.isEmpty {
                variants.append("\(name) \(hint)")
            }
            variants.append(normalizeQuery(baseQuery))
            return variants.filter { !$0.isEmpty }.uniqued()
        }

        var normalizedName: String {
            normalizeQuery(objectName)
        }

        var compactCategoryHint: String {
            categoryHint
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        var anchorTokens: [String] {
            let parts = normalizedName
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 }
            guard !parts.isEmpty else { return [normalizedName] }
            if parts.count == 1 { return parts }
            // Prefer the subject noun (usually the last word): "great white shark" -> shark.
            if let last = parts.last, last.count >= 4 { return [last] }
            return Array(parts.suffix(2))
        }

        var nameTokens: [String] {
            tokens(from: objectName)
        }

        var categoryTokens: [String] {
            tokens(from: "\(categoryHint) \(categoryTitle)")
                .filter { !Self.genericTokens.contains($0) }
        }

        func matchesAnchors(in text: String) -> Bool {
            let haystack = text.lowercased()
            return anchorTokens.contains { haystack.contains($0) }
        }

        private static let genericTokens: Set<String> = [
            "wild", "animal", "animals", "photo", "real", "life", "hunt", "prey", "predator",
            "apex", "giant", "baby", "kind", "kinds", "wildlife", "creature", "creatures",
        ]

        private func tokens(from text: String) -> [String] {
            text.lowercased()
                .replacingOccurrences(of: "/", with: " ")
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 && !Self.genericTokens.contains($0) }
        }

        private func normalizeQuery(_ query: String) -> String {
            var text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            while text.hasSuffix(" photo") || text.hasSuffix(" picture") || text.hasSuffix(" image") {
                if text.hasSuffix(" photo") { text = String(text.dropLast(6)) }
                else if text.hasSuffix(" picture") { text = String(text.dropLast(8)) }
                else if text.hasSuffix(" image") { text = String(text.dropLast(6)) }
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private struct ImageCandidate {
        let url: URL
        let score: Int
    }

    private static func relevanceScore(text: String, context: SearchContext, strict: Bool) -> Int? {
        let haystack = text.lowercased()
        guard !haystack.isEmpty else { return strict ? nil : 0 }
        guard context.matchesAnchors(in: haystack) else { return nil }

        var score = 800
        for token in context.nameTokens where haystack.contains(token) {
            score += 300
        }
        for token in context.categoryTokens where haystack.contains(token) {
            score += 80
        }
        return score
    }

    private static func scorePixabayHit(_ hit: PixabayResponse.Hit, context: SearchContext, strict: Bool) -> Int {
        guard let tags = hit.tags, !tags.isEmpty else { return strict ? 0 : 0 }
        guard var score = relevanceScore(text: tags, context: context, strict: strict) else { return 0 }
        if let width = hit.imageWidth, let height = hit.imageHeight {
            score += min(width, 800) / 8
            if width >= 640 && height >= 480 { score += 60 }
        }
        return score
    }

    private static func scorePexelsPhoto(_ photo: PexelsResponse.Photo, context: SearchContext, strict: Bool) -> Int {
        guard let alt = photo.alt, !alt.isEmpty else { return 0 }
        guard var score = relevanceScore(text: alt, context: context, strict: strict) else { return 0 }
        if let width = photo.width, let height = photo.height {
            score += min(width, 800) / 8
            if width >= 640 && height >= 480 { score += 60 }
        }
        return score
    }

    private static func pixabayHits(query: String, category: String?, page: Int = 1) async -> [PixabayResponse.Hit] {
        guard let apiKey = ImageSearchConfig.pixabayAPIKey else { return [] }
        var components = URLComponents(string: "https://pixabay.com/api/")
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "image_type", value: "photo"),
            URLQueryItem(name: "safesearch", value: "true"),
            URLQueryItem(name: "per_page", value: "20"),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "orientation", value: "all"),
        ]
        if let category, !category.isEmpty {
            items.append(URLQueryItem(name: "category", value: category))
        }
        components?.queryItems = items
        guard let url = components?.url else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            let decoded = try JSONDecoder().decode(PixabayResponse.self, from: data)
            return decoded.hits ?? []
        } catch {
            return []
        }
    }

    private static func pexelsPhotos(query: String, page: Int = 1) async -> [PexelsResponse.Photo] {
        guard let apiKey = ImageSearchConfig.pexelsAPIKey else { return [] }
        var components = URLComponents(string: "https://api.pexels.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "15"),
            URLQueryItem(name: "page", value: String(max(1, page))),
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            let decoded = try JSONDecoder().decode(PexelsResponse.self, from: data)
            return decoded.photos ?? []
        } catch {
            return []
        }
    }

    private static func searchGoogleImages(query: String) async -> URL? {
        guard
            let apiKey = ImageSearchConfig.googleAPIKey,
            let cx = ImageSearchConfig.googleSearchEngineID
        else { return nil }

        var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: cx),
            URLQueryItem(name: "q", value: "\(query) photo"),
            URLQueryItem(name: "searchType", value: "image"),
            URLQueryItem(name: "num", value: "8"),
            URLQueryItem(name: "safe", value: "active"),
            URLQueryItem(name: "imgSize", value: "large"),
            URLQueryItem(name: "imgType", value: "photo"),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(GoogleImageSearchResponse.self, from: data)
            return decoded.items?.first?.link.flatMap(URL.init(string:))
        } catch {
            return nil
        }
    }

    private static func searchCommons(query: String) async -> URL? {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(query) photo"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "10"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|mime|size"),
            URLQueryItem(name: "iiurlwidth", value: "1024"),
        ]
        guard let url = components?.url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let decoded = try JSONDecoder().decode(WikimediaResponse.self, from: data)
            let pages = decoded.query?.pages?.values.sorted { ($0.index ?? 0) < ($1.index ?? 0) } ?? []
            for page in pages {
                guard let info = page.imageinfo?.first else { continue }
                let mime = info.mime ?? ""
                guard mime.contains("jpeg") || mime.contains("jpg") || mime.contains("png") || mime.contains("webp") else {
                    continue
                }
                if let thumb = info.thumburl, let thumbURL = URL(string: thumb) { return thumbURL }
                if let full = info.url, let fullURL = URL(string: full) { return fullURL }
            }
            return nil
        } catch {
            return nil
        }
    }
}

private struct PixabayResponse: Decodable {
    var hits: [Hit]?

    struct Hit: Decodable {
        var tags: String?
        var largeImageURL: String?
        var webformatURL: String?
        var imageWidth: Int?
        var imageHeight: Int?
        var views: Int?

        var imageURL: URL? {
            if let largeImageURL, let url = URL(string: largeImageURL) { return url }
            if let webformatURL, let url = URL(string: webformatURL) { return url }
            return nil
        }
    }
}

private struct PexelsResponse: Decodable {
    var photos: [Photo]?

    struct Photo: Decodable {
        var alt: String?
        var width: Int?
        var height: Int?
        var src: Sources?

        var imageURL: URL? {
            if let large2x = src?.large2x, let url = URL(string: large2x) { return url }
            if let large = src?.large, let url = URL(string: large) { return url }
            if let original = src?.original, let url = URL(string: original) { return url }
            return nil
        }
    }

    struct Sources: Decodable {
        var original: String?
        var large2x: String?
        var large: String?
    }
}

private struct GoogleImageSearchResponse: Decodable {
    var items: [Item]?

    struct Item: Decodable {
        var link: String?
    }
}

private struct WikimediaResponse: Decodable {
    var query: Query?

    struct Query: Decodable {
        var pages: [String: Page]?
    }

    struct Page: Decodable {
        var index: Int?
        var imageinfo: [ImageInfo]?
    }

    struct ImageInfo: Decodable {
        var thumburl: String?
        var url: String?
        var mime: String?
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
