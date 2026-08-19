import Foundation

struct RemoteCatalogConfig: Codable, Sendable {
    var manifestURL: String
    var manifestVersion: Int
    var enabled: Bool

    static let disabled = RemoteCatalogConfig(manifestURL: "", manifestVersion: 0, enabled: false)
}

struct RemoteCatalogStatus: Sendable {
    var bundledRoundCount: Int
    var remoteRoundCount: Int
    var mergedRoundCount: Int
    var source: String
    var detail: String

    var summary: String {
        "\(source): \(mergedRoundCount) hunts (\(bundledRoundCount) bundled + \(remoteRoundCount) remote). \(detail)"
    }
}

private struct RemoteManifestCacheMeta: Codable {
    var manifestVersion: Int
    var fetchedAt: Date
}

private struct RemoteManifestPatch: Codable {
    var rounds: [HuntRound]
}

enum ContentLoader {
    private static let maxRemoteRounds = 100
    private static let remoteCacheName = "manifest-remote.json"
    private static let remoteMetaName = "manifest-remote-meta.json"

    static func loadBundled() throws -> HuntManifest {
        guard let url = bundleManifestURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try decodeManifest(data)
    }

    static func loadRemoteConfig() -> RemoteCatalogConfig {
        guard let url = bundleRemoteConfigURL(),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(RemoteCatalogConfig.self, from: data) else {
            return .disabled
        }
        return config
    }

    @MainActor
    static func loadMergedManifest(forceRefresh: Bool = false) async -> (manifest: HuntManifest, status: RemoteCatalogStatus) {
        let bundled: HuntManifest
        do {
            bundled = try loadBundled()
        } catch {
            let empty = HuntManifest(physicalMarkerWidthMeters: 0.1, markerCount: 12, rounds: [])
            return (
                empty,
                RemoteCatalogStatus(
                    bundledRoundCount: 0,
                    remoteRoundCount: 0,
                    mergedRoundCount: 0,
                    source: "Error",
                    detail: "Bundled manifest missing."
                )
            )
        }

        let config = loadRemoteConfig()
        guard config.enabled, !config.manifestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let remoteURL = URL(string: config.manifestURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return (
                bundled,
                RemoteCatalogStatus(
                    bundledRoundCount: bundled.rounds.count,
                    remoteRoundCount: 0,
                    mergedRoundCount: bundled.rounds.count,
                    source: "Bundled",
                    detail: config.enabled ? "Remote URL not configured." : "Remote catalog disabled."
                )
            )
        }

        var remoteRounds: [HuntRound] = []
        var source = "Bundled"
        var detail = "Remote catalog unavailable."

        if forceRefresh || shouldFetchRemote(config: config) {
            if let fetched = await fetchRemoteRounds(from: remoteURL) {
                remoteRounds = fetched
                saveRemoteCache(fetched, version: config.manifestVersion)
                source = "Bundled + remote"
                detail = "Fetched \(fetched.count) remote hunt(s)."
            } else if let cached = loadRemoteCache() {
                remoteRounds = cached
                source = "Bundled + cached remote"
                detail = "Fetch failed; using cached remote hunts (\(cached.count))."
            }
        } else if let cached = loadRemoteCache() {
            remoteRounds = cached
            source = "Bundled + cached remote"
            detail = "Using cached remote hunts (\(cached.count))."
        } else if let fetched = await fetchRemoteRounds(from: remoteURL) {
            remoteRounds = fetched
            saveRemoteCache(fetched, version: config.manifestVersion)
            source = "Bundled + remote"
            detail = "Fetched \(fetched.count) remote hunt(s)."
        }

        let merged = mergeManifest(bundled: bundled, remoteRounds: remoteRounds)
        let appended = merged.rounds.count - bundled.rounds.count
        return (
            merged,
            RemoteCatalogStatus(
                bundledRoundCount: bundled.rounds.count,
                remoteRoundCount: appended,
                mergedRoundCount: merged.rounds.count,
                source: source,
                detail: detail
            )
        )
    }

    static func mergeManifest(bundled: HuntManifest, remoteRounds: [HuntRound]) -> HuntManifest {
        let bundledIDs = Set(bundled.rounds.map(\.id))
        var seenRemote = Set<String>()
        let extra = remoteRounds.filter { round in
            guard validateRound(round) else { return false }
            guard !bundledIDs.contains(round.id) else { return false }
            guard !seenRemote.contains(round.id) else { return false }
            seenRemote.insert(round.id)
            return true
        }.prefix(maxRemoteRounds)

        var merged = bundled
        merged.rounds.append(contentsOf: extra)
        return merged
    }

    private static func validateRound(_ round: HuntRound) -> Bool {
        guard !round.id.isEmpty, !round.title.isEmpty, !round.objects.isEmpty else { return false }
        return round.objects.allSatisfy { object in
            !object.id.isEmpty && !object.name.isEmpty && object.markerId.hasPrefix("marker-")
        }
    }

    private static func shouldFetchRemote(config: RemoteCatalogConfig) -> Bool {
        guard let meta = loadRemoteCacheMeta() else { return true }
        return meta.version < config.manifestVersion
    }

    private static func fetchRemoteRounds(from url: URL) async -> [HuntRound]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try parseRemoteRounds(data)
        } catch {
            return nil
        }
    }

    private static func parseRemoteRounds(_ data: Data) throws -> [HuntRound] {
        if let manifest = try? decodeManifest(data) {
            return manifest.rounds
        }
        let patch = try JSONDecoder().decode(RemoteManifestPatch.self, from: data)
        return patch.rounds
    }

    private static func decodeManifest(_ data: Data) throws -> HuntManifest {
        try JSONDecoder().decode(HuntManifest.self, from: data)
    }

    private static func applicationSupportDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private static func saveRemoteCache(_ rounds: [HuntRound], version: Int) {
        guard let base = applicationSupportDirectory() else { return }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let payload = RemoteManifestPatch(rounds: rounds)
        let cacheURL = base.appendingPathComponent(remoteCacheName)
        let metaURL = base.appendingPathComponent(remoteMetaName)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: cacheURL, options: .atomic)
        }
        let meta = RemoteManifestCacheMeta(manifestVersion: version, fetchedAt: Date())
        if let metaData = try? JSONEncoder().encode(meta) {
            try? metaData.write(to: metaURL, options: .atomic)
        }
    }

    private static func loadRemoteCacheMeta() -> RemoteCatalogCacheMeta? {
        guard let base = applicationSupportDirectory() else { return nil }
        let metaURL = base.appendingPathComponent(remoteMetaName)
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(RemoteManifestCacheMeta.self, from: data) else {
            return nil
        }
        return RemoteCatalogCacheMeta(version: meta.manifestVersion, fetchedAt: meta.fetchedAt)
    }

    private struct RemoteCatalogCacheMeta {
        var version: Int
        var fetchedAt: Date
    }

    private static func loadRemoteCache() -> [HuntRound]? {
        guard let base = applicationSupportDirectory() else { return nil }
        let cacheURL = base.appendingPathComponent(remoteCacheName)
        guard let data = try? Data(contentsOf: cacheURL),
              let patch = try? JSONDecoder().decode(RemoteManifestPatch.self, from: data) else {
            return nil
        }
        return patch.rounds
    }

    private static func bundleManifestURL() -> URL? {
        resourceURL(name: "manifest", ext: "json", alsoTry: ["Content", "Resources", "Markers"])
    }

    private static func bundleRemoteConfigURL() -> URL? {
        resourceURL(name: "remote-config", ext: "json", alsoTry: ["Resources"])
    }

    private static func resourceURL(name: String, ext: String, alsoTry: [String]) -> URL? {
        let bundle = Bundle.main
        var dirs: [String?] = [nil] + alsoTry.map { Optional($0) }
        for sub in dirs {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub) {
                return url
            }
        }
        return bundle.urls(forResourcesWithExtension: ext, subdirectory: nil)?
            .first { $0.deletingPathExtension().lastPathComponent == name }
    }
}
