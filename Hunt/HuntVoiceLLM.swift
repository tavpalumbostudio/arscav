import Foundation
import LLM

enum HuntVoiceLLMError: Error, LocalizedError {
    case downloadFailed(String)
    case loadFailed
    case fileTooSmall(bytes: Int64)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let detail):
            return "Download failed: \(detail)"
        case .loadFailed:
            return "Model file downloaded but failed to load."
        case .fileTooSmall(let bytes):
            return "Download looks corrupt (\(bytes) bytes). Tap Reload model."
        }
    }
}

struct HuntVoiceLLMResult {
    let model: LLM?
    let errorMessage: String?
}

/// SmolLM2-135M for short spoken hunt lines. Cached under Application Support after first download.
enum HuntVoiceLLM {
    private static let cacheFileName = "SmolLM2-135M-Instruct-Q4_K_M.gguf"
    private static let downloadURL = URL(
        string: "https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf"
    )!
    private static let systemPrompt = "Write one short kid-safe scavenger hunt sentence."
    private static let minFileBytes: Int64 = 50_000_000

    /// Room for ChatML wrapper + instruction + reply. 192 was too tight for the full prompt.
    private static let maxTokenCount: Int32 = 512
    private static let historyLimit = 0

    static func load(onProgress: @escaping @Sendable (Double) -> Void) async -> HuntVoiceLLMResult {
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)
        let destination = cacheDir.appendingPathComponent(cacheFileName)

        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try await downloadIfNeeded(to: destination, onProgress: onProgress)
            onProgress(0.98)

            let model = await Task.detached(priority: .utility) {
                LLM(
                    from: destination,
                    template: .chatML(systemPrompt),
                    topK: 30,
                    temp: 0.65,
                    historyLimit: historyLimit,
                    maxTokenCount: maxTokenCount
                )
            }.value

            guard let model else {
                let message = HuntVoiceLLMError.loadFailed.localizedDescription
                return HuntVoiceLLMResult(model: nil, errorMessage: message)
            }

            // Prime llama graphs so the first dev-menu tap is not a multi-minute cold start.
            _ = await model.getCompletion(from: model.preprocess("Say hello.", []))

            onProgress(1)
            return HuntVoiceLLMResult(model: model, errorMessage: nil)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return HuntVoiceLLMResult(model: nil, errorMessage: message)
        }
    }

    private static func downloadIfNeeded(
        to destination: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            let size = fileSize(at: destination)
            if size >= minFileBytes {
                onProgress(1)
                return
            }
            try? FileManager.default.removeItem(at: destination)
        }

        onProgress(0.01)
        let tempURL = try await downloadFile(from: downloadURL, onProgress: onProgress)

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)

        let size = fileSize(at: destination)
        guard size >= minFileBytes else {
            try? FileManager.default.removeItem(at: destination)
            throw HuntVoiceLLMError.fileTooSmall(bytes: size)
        }
        onProgress(0.95)
    }

    private static func downloadFile(
        from url: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("ARScav/1.0", forHTTPHeaderField: "User-Agent")

        var observation: NSKeyValueObservation?
        let tempURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: HuntVoiceLLMError.downloadFailed(error.localizedDescription))
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: HuntVoiceLLMError.downloadFailed("Empty response"))
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode / 100 != 2 {
                    continuation.resume(throwing: HuntVoiceLLMError.downloadFailed("HTTP \(http.statusCode)"))
                    return
                }
                continuation.resume(returning: tempURL)
            }

            observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                onProgress(min(0.94, max(0.01, progress.fractionCompleted * 0.94)))
            }
            task.resume()
        }
        _ = observation
        return tempURL
    }

    private static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
