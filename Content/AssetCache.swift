import Foundation
import UIKit

actor AssetCache {
    static let shared = AssetCache()

    private let folder: URL
    private var memory: [String: Data] = [:]

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func fileURL(for id: String) -> URL {
        folder.appendingPathComponent("\(id).jpg")
    }

    func imageData(for id: String) -> Data? {
        if let data = memory[id] { return data }
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try? Data(contentsOf: url)
        memory[id] = data
        return data
    }

    func store(_ data: Data, for id: String) {
        memory[id] = data
        try? data.write(to: fileURL(for: id), options: .atomic)
    }

    func uiImage(for id: String) -> UIImage? {
        guard let data = imageData(for: id) else { return nil }
        return UIImage(data: data)
    }
}
