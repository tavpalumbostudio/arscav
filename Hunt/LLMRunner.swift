import Foundation
import LLM

enum LLMError: Error {
    case unavailable
    case timedOut
}

/// On-device SmolLM2-135M with canned fallback when loading or inference is too slow.
@MainActor
final class LLMRunner {
    static let shared = LLMRunner()

    private var bot: LLM?
    private var loadTask: Task<ModelLoadStatus, Never>?
    private var isGenerating = false
    private(set) var lastLoadError: String?

    func unload() {
        loadTask?.cancel()
        loadTask = nil
        bot?.stop()
        bot = nil
        isGenerating = false
        lastLoadError = nil
    }

    var isReady: Bool { bot != nil }

    func warmup(onProgress: @escaping (Double) -> Void = { _ in }) async -> ModelLoadStatus {
        if bot != nil {
            lastLoadError = nil
            return .ready
        }
        if let loadTask { return await loadTask.value }

        let task = Task { [weak self] () -> ModelLoadStatus in
            let progressHandler: @Sendable (Double) -> Void = { value in
                Task { @MainActor in onProgress(value) }
            }
            let result = await HuntVoiceLLM.load(onProgress: progressHandler)
            await MainActor.run {
                self?.bot = result.model
                self?.lastLoadError = result.errorMessage
            }
            return result.model == nil ? .unavailable : .ready
        }
        loadTask = task
        let status = await task.value
        loadTask = nil
        return status
    }

    func generate(_ prompt: String, timeout: TimeInterval) async throws -> String {
        guard let bot else { throw LLMError.unavailable }
        guard !isGenerating else { throw LLMError.unavailable }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMError.unavailable }

        isGenerating = true
        defer { isGenerating = false }

        do {
            return try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { @MainActor in
                    let processed = bot.preprocess(trimmed, [])
                    return await bot.getCompletion(from: processed)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw LLMError.timedOut
                }
                guard let result = try await group.next() else { throw LLMError.unavailable }
                group.cancelAll()
                return result
            }
        } catch LLMError.timedOut {
            bot.stop()
            throw LLMError.timedOut
        }
    }
}
