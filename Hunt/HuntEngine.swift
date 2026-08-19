import Combine
import Foundation
import UIKit

@MainActor
final class HuntEngine: ObservableObject {
    @Published var manifest: HuntManifest
    @Published var roundIndex = 0
    @Published var foundIDs: Set<String> = []
    @Published var revealedIDs: Set<String> = []
    @Published var phase: HuntPhase = .selecting
    @Published var showCollection = false
    @Published var faceImages: [String: UIImage] = [:]
    @Published var statusLine = "Loading hunt…"
    @Published var roundToken = 0
    @Published var imagesLoaded = 0
    @Published var imagesTotal = 0
    @Published var nextImagesLoaded = 0
    @Published var nextImagesTotal = 0
    @Published var modelStatus: ModelLoadStatus = .idle
    @Published var modelDownloadProgress: Double = 0
    @Published var modelLoadError: String?
    @Published var showContentPanel = true
    @Published var markerCard: MarkerCardPresentation?
    @Published var isDevMenuOpen = false
    @Published var showRoundSuccess = false
    @Published var lastCompletedRoundTitle = ""
    @Published private(set) var lastCompletedRoundTargets: [HuntObject] = []
    @Published var refreshingCardImageID: String?
    @Published private(set) var hunterPortrait: UIImage?
    @Published private(set) var pickerThumbnails: [String: UIImage] = [:]
    @Published private(set) var pickerThumbnailsLoaded = 0
    @Published private(set) var pickerThumbnailsTotal = 0
    /// Cached card backs keyed by roundToken + marker id.
    private var backImages: [String: UIImage] = [:]
    /// 0 uses manifest default; otherwise 1–24 markers (marker-01 … marker-NN) are active.
    @Published var activeMarkerCount = 0
    /// When enabled, scanned cards zoom in then flip automatically after a short pause.
    @Published var autoFlipCards = false
    @Published var playerName: String
    @Published var familyPlayMode: FamilyPlayMode
    @Published var grownUpName: String
    @Published var helperName: String
    @Published var movementPromptsEnabled: Bool
    @Published var targetsPerRound: Int
    @Published var shuffleTargets: Bool
    @Published private(set) var sessionTargetIDs: [String] = []
    @Published private(set) var remoteCatalogStatus = ""

    let speech = SpeechPrompter()
    private let prompts: PromptWriter
    let physicalWidth: Float

    private var cardMarkerId: String?
    private var visibleMarkers: Set<String> = []
    private var dismissTask: Task<Void, Never>?
    private var flipSpeechTask: Task<Void, Never>?
    private var idleChatterTask: Task<Void, Never>?
    private var idleChatterIndex = 0
    private var wonderLineIndex = 0
    private var coopLineIndex = 0
    private var movementLineIndex = 0
    private var imageRefreshAttempts: [String: Int] = [:]

    private enum Pacing {
        static let cardRevealSpeechDelay: UInt64 = 1_800_000_000
        static let afterCheerDelay: UInt64 = 3_200_000_000
        static let beforeNextPromptDelay: UInt64 = 1_400_000_000
        static let beforeNextRoundIntroDelay: UInt64 = 1_800_000_000
        static let roundSuccessSpeechDelay: UInt64 = 900_000_000
        static let idleChatterInitialDelay: UInt64 = 14_000_000_000
        static let idleChatterMinInterval: UInt64 = 18_000_000_000
        static let idleChatterMaxInterval: UInt64 = 25_000_000_000
    }

    func setPlayerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "Cosmo" : trimmed
        playerName = resolved
        PlayerSettings.saveName(resolved)
    }

    func setFamilyPlayMode(_ mode: FamilyPlayMode) {
        familyPlayMode = mode
        PlayerSettings.saveFamilyPlayMode(mode)
    }

    func setGrownUpName(_ name: String) {
        grownUpName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        PlayerSettings.saveGrownUpName(grownUpName)
    }

    func setHelperName(_ name: String) {
        helperName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        PlayerSettings.saveHelperName(helperName)
    }

    func setMovementPromptsEnabled(_ enabled: Bool) {
        movementPromptsEnabled = enabled
        PlayerSettings.saveMovementPromptsEnabled(enabled)
    }

    func setTargetsPerRound(_ count: Int) {
        let clamped = min(max(count, 1), 4)
        targetsPerRound = clamped
        PlayerSettings.saveTargetsPerRound(clamped)
    }

    func setShuffleTargets(_ enabled: Bool) {
        shuffleTargets = enabled
        PlayerSettings.saveShuffleTargets(enabled)
    }

    func testIdleChatter(speak: Bool = true) -> String {
        guard let target = currentTarget ?? requiredTargets.first else {
            return "No active target for idle chatter."
        }
        let line = IdleChatter.line(
            playerName: playerName,
            target: target,
            round: currentRound,
            familyPlayMode: familyPlayMode,
            movementPromptsEnabled: movementPromptsEnabled,
            grownUpName: grownUpName,
            helperName: helperName,
            styleIndex: idleChatterIndex
        )
        idleChatterIndex += 1
        if speak {
            speech.speak(line, roundIndex: roundIndex, kind: .prompt)
        }
        return line
    }

    func testWonderLine(speak: Bool = true) -> String {
        guard let target = currentTarget ?? requiredTargets.first else {
            return "No active target for wonder line."
        }
        let line = WonderLines.line(
            playerName: playerName,
            target: target,
            round: currentRound,
            styleIndex: wonderLineIndex
        )
        wonderLineIndex += 1
        if speak {
            speech.speak(line, roundIndex: roundIndex, kind: .prompt)
        }
        return line
    }

    func testCoopLine(speak: Bool = true) -> String {
        guard familyPlayMode != .solo else {
            return "Set a family co-op mode first (not Solo)."
        }
        let line = CoopPrompts.line(
            moment: .idle,
            context: promptContext,
            styleIndex: coopLineIndex
        ) ?? "No co-op line available."
        coopLineIndex += 1
        if speak {
            speech.speak(line, roundIndex: roundIndex, kind: .prompt)
        }
        return line
    }

    var hasNextRound: Bool {
        roundIndex + 1 < manifest.rounds.count
    }

    var currentRound: HuntRound {
        manifest.rounds[roundIndex]
    }

    var currentTarget: HuntObject? {
        requiredTargets.first { !foundIDs.contains($0.id) && isObjectActive($0) }
    }

    private var requiredTargets: [HuntObject] {
        sessionTargetIDs.compactMap { currentRound.object(id: $0) }
    }

    private var promptContext: PromptContext {
        PromptContext(
            playerName: playerName,
            familyPlayMode: familyPlayMode,
            grownUpName: grownUpName,
            helperName: helperName,
            sessionTargetIDs: sessionTargetIDs,
            foundIDs: foundIDs,
            round: currentRound
        )
    }

    private func shuffleSessionTargets() {
        let pool = activeObjects(in: currentRound).map(\.id)
        let count = min(max(targetsPerRound, 1), 4, pool.count)
        guard count > 0 else {
            sessionTargetIDs = []
            return
        }
        if shuffleTargets {
            sessionTargetIDs = Array(pool.shuffled().prefix(count))
        } else {
            let manifestTargets = currentRound.targets.filter { pool.contains($0) }
            var ids = Array(manifestTargets.prefix(count))
            if ids.count < count {
                let extras = pool.filter { !ids.contains($0) }
                ids.append(contentsOf: extras.prefix(count - ids.count))
            }
            sessionTargetIDs = ids
        }
    }

    private var allRequiredTargetsFound: Bool {
        let ids = Set(requiredTargets.map(\.id))
        guard !ids.isEmpty else { return false }
        return ids.isSubset(of: foundIDs)
    }

    var resolvedMarkerLimit: Int {
        let chosen = activeMarkerCount == 0 ? manifest.resolvedMarkerCount : activeMarkerCount
        return min(max(chosen, 1), 24)
    }

    func activeObjects(in round: HuntRound) -> [HuntObject] {
        round.objects.filter { object in
            guard let number = object.markerNumber else { return false }
            return number >= 1 && number <= resolvedMarkerLimit
        }
    }

    func setMarkerCount(_ count: Int) {
        let clamped = min(max(count, 0), 24)
        guard clamped != activeMarkerCount else { return }
        activeMarkerCount = clamped
        backImages.removeAll()
        foundIDs.removeAll()
        revealedIDs.removeAll()
        shuffleSessionTargets()
        resetMarkerCardForNewRound()
        roundToken += 1
        showContentPanel = true
        Task {
            await self.prefetch(roundIndex: self.roundIndex, tracking: .current)
            await self.speakIntroAndPrompt()
            self.scheduleHideContentPanelIfReady()
        }
    }

    init(manifest: HuntManifest) {
        self.manifest = manifest
        physicalWidth = Float(manifest.physicalMarkerWidthMeters)
        prompts = PromptWriter(runner: .shared)
        playerName = PlayerSettings.loadName()
        familyPlayMode = PlayerSettings.loadFamilyPlayMode()
        grownUpName = PlayerSettings.loadGrownUpName()
        helperName = PlayerSettings.loadHelperName()
        movementPromptsEnabled = PlayerSettings.loadMovementPromptsEnabled()
        targetsPerRound = PlayerSettings.loadTargetsPerRound()
        shuffleTargets = PlayerSettings.loadShuffleTargets()
    }

    func prepare() async {
        HuntAudioSession.activate()
        HuntSoundFX.shared.prepare()
        phase = .selecting
        sessionTargetIDs = []
        statusLine = "Choose a hunt"
        Task { await loadModel() }
        Task { await prefetchPickerThumbnails() }
    }

    func applyMergedManifest(_ manifest: HuntManifest, status: RemoteCatalogStatus) async {
        remoteCatalogStatus = status.summary
        let previousIDs = Set(self.manifest.rounds.map(\.id))
        self.manifest = manifest
        let newRounds = manifest.rounds.filter { !previousIDs.contains($0.id) }
        if !newRounds.isEmpty {
            await prefetchPickerThumbnails(for: newRounds)
        }
    }

    func reloadRemoteCatalog(forceRefresh: Bool = true) async -> String {
        let result = await ContentLoader.loadMergedManifest(forceRefresh: forceRefresh)
        await applyMergedManifest(result.manifest, status: result.status)
        return result.status.summary
    }

    func start() async {
        await prepare()
    }

    func backImage(for markerId: String) -> UIImage {
        let key = "\(roundToken)-\(markerId)"
        if let cached = backImages[key] { return cached }
        let number = markerNumber(from: markerId) ?? 0
        let image = CardTextureFactory.makeBack(
            markerNumber: number,
            round: currentRound,
            roundIndex: roundIndex
        )
        backImages[key] = image
        return image
    }

    func object(forMarker markerId: String) -> HuntObject? {
        guard isMarkerActive(markerId) else { return nil }
        return currentRound.object(markerId: markerId)
    }

    private func isMarkerActive(_ markerId: String) -> Bool {
        guard let number = markerNumber(from: markerId) else { return false }
        return number >= 1 && number <= resolvedMarkerLimit
    }

    private func markerNumber(from markerId: String) -> Int? {
        let prefix = "marker-"
        guard markerId.hasPrefix(prefix) else { return nil }
        return Int(markerId.dropFirst(prefix.count))
    }

    func faceImage(for object: HuntObject) -> UIImage {
        if let cached = faceImages[object.id] { return cached }
        let photo = faceImages["photo-\(object.id)"]
        let composed = CardTextureFactory.makeFace(image: photo, name: object.name, emoji: object.emoji)
        faceImages[object.id] = composed
        return composed
    }

    func refreshCardImage(for objectId: String) async {
        guard let object = currentRound.object(id: objectId) else { return }
        guard refreshingCardImageID == nil else { return }

        refreshingCardImageID = objectId
        defer { refreshingCardImageID = nil }

        let attempt = (imageRefreshAttempts[objectId] ?? 0) + 1
        imageRefreshAttempts[objectId] = attempt

        let photo = await ImageSearchService.refreshImage(
            for: object,
            in: currentRound,
            attempt: attempt
        )
        guard let photo else { return }

        faceImages["photo-\(object.id)"] = photo
        faceImages[object.id] = CardTextureFactory.makeFace(
            image: photo,
            name: object.name,
            emoji: object.emoji
        )
        objectWillChange.send()
    }

    func isRefreshingCardImage(_ objectId: String) -> Bool {
        refreshingCardImageID == objectId
    }

    private func isObjectActive(_ object: HuntObject) -> Bool {
        guard let markerId = object.markerNumber else { return false }
        return markerId >= 1 && markerId <= resolvedMarkerLimit
    }

    func handleTap(objectId: String) -> RevealOutcome {
        guard phase == .playing, let object = currentRound.object(id: objectId) else {
            return .alreadyRevealed
        }
        if foundIDs.contains(objectId) {
            return .alreadyFound
        }

        let isTarget = sessionTargetIDs.contains(objectId)
        let firstReveal = revealedIDs.insert(objectId).inserted

        if isTarget, isObjectActive(object) {
            foundIDs.insert(object.id)
            playSuccess()
            Task { @MainActor in
                await self.advanceAfterCollect(found: object)
            }
            return .collected
        }

        if !firstReveal {
            return .alreadyRevealed
        }

        playError()
        return .decoy
    }

    func repeatPrompt() {
        guard phase == .playing, currentTarget != nil else { return }
        Task { await speakFindPrompt(rephrase: true) }
    }

    func testPrompt(_ test: LLMTestPrompt, speak: Bool = false) async -> String {
        let kind = testPromptKind(test)
        let result = await prompts.lineWithMetadata(for: kind, context: promptContext)
        if speak {
            speech.speak(result.text, roundIndex: roundIndex, kind: voiceKind(for: kind))
        }
        return result.devSummary
    }

    func testCannedPrompt(_ test: LLMTestPrompt, speak: Bool = false) -> String {
        let kind = testPromptKind(test)
        let line = PromptPersonalizer.personalize(
            CannedPrompts.line(for: kind, round: currentRound),
            name: playerName,
            chance: kindPersonalizationChance(kind)
        )
        if speak {
            speech.speak(line, roundIndex: roundIndex, kind: voiceKind(for: kind))
        }
        return PromptLineResult(
            text: line,
            source: .cannedExplicit,
            rawLLMOutput: nil,
            latencySeconds: nil
        ).devSummary
    }

    func reloadVoiceModel() async {
        LLMRunner.shared.unload()
        modelStatus = .loading
        modelDownloadProgress = 0
        modelLoadError = nil
        modelStatus = await LLMRunner.shared.warmup { [weak self] progress in
            self?.modelDownloadProgress = progress
        }
        modelLoadError = LLMRunner.shared.lastLoadError
        if modelStatus == .ready {
            modelDownloadProgress = 1
        }
    }

    private func testPromptKind(_ test: LLMTestPrompt) -> PromptKind {
        let targetName = currentTarget?.name ?? requiredTargets.first?.name ?? "treasure"
        let decoyName = sampleDecoyName() ?? "decoy card"
        return test.promptKind(targetName: targetName, decoyName: decoyName)
    }

    private func sampleDecoyName() -> String? {
        activeObjects(in: currentRound).first { object in
            !sessionTargetIDs.contains(object.id)
        }?.name
    }

    private func voiceKind(for kind: PromptKind) -> SillyVoiceBank.Kind {
        switch kind {
        case .decoy: return .decoy
        case .collected, .roundComplete, .complete: return .success
        case .intro, .find, .findRephrase: return .prompt
        }
    }

    func startNewGame(categoryIndex: Int) async {
        guard manifest.rounds.indices.contains(categoryIndex) else { return }
        stopIdleChatter()
        speech.stop()
        showRoundSuccess = false
        roundIndex = categoryIndex
        backImages.removeAll()
        foundIDs.removeAll()
        revealedIDs.removeAll()
        phase = .playing
        showCollection = false
        isDevMenuOpen = false
        shuffleSessionTargets()
        resetMarkerCardForNewRound()
        roundToken += 1
        showContentPanel = true
        nextImagesLoaded = 0
        nextImagesTotal = 0
        await prefetch(roundIndex: roundIndex, tracking: .current)
        await speakIntroAndPrompt()
        scheduleHideContentPanelIfReady()
        if manifest.rounds.indices.contains(roundIndex + 1) {
            Task { await self.prefetch(roundIndex: self.roundIndex + 1, tracking: .next) }
        }
    }

    func dismissMarkerCard() {
        dismissTask?.cancel()
        dismissTask = nil
        markerCard = nil
        cardMarkerId = nil
        if shouldRunIdleChatter {
            startIdleChatter()
        }
    }

    func notifyDevMenuOpened() {
        stopIdleChatter()
    }

    func notifyDevMenuClosed() {
        if shouldRunIdleChatter {
            startIdleChatter()
        }
    }

    /// Shows a card in the hunt overlay without AR tracking (simulator / dev menu).
    func previewMarkerCard(markerNumber: Int, flipped: Bool = false) {
        stopIdleChatter()
        let markerId = String(format: "marker-%02d", markerNumber)
        guard let object = object(forMarker: markerId) else { return }
        dismissTask?.cancel()
        dismissTask = nil
        cardMarkerId = markerId
        markerCard = MarkerCardPresentation(
            markerId: markerId,
            objectId: object.id,
            isFlipped: flipped,
            isPreview: true
        )
    }

    func previewObjectName(for markerNumber: Int) -> String? {
        let markerId = String(format: "marker-%02d", markerNumber)
        return object(forMarker: markerId)?.name
    }

    func markerDidTrack(_ markerId: String) {
        guard !isDevMenuOpen else { return }
        stopIdleChatter()
        if markerCard?.isPreview == true {
            dismissMarkerCard()
        }
        dismissTask?.cancel()
        dismissTask = nil
        let becameVisible = visibleMarkers.insert(markerId).inserted

        guard let object = object(forMarker: markerId) else { return }
        let flipped = revealedIDs.contains(object.id)
        cardMarkerId = markerId
        markerCard = MarkerCardPresentation(markerId: markerId, objectId: object.id, isFlipped: flipped)

        if becameVisible, flipped {
            scheduleDelayedSpeech { self.speakObjectName(object) }
        }
    }

    func markerDidLoseTrack(_ markerId: String) {
        visibleMarkers.remove(markerId)
        guard cardMarkerId == markerId else { return }
        scheduleMarkerCardDismiss()
    }

    func flipMarkerCard() {
        guard var card = markerCard else { return }
        if card.isPreview {
            HuntSoundFX.shared.playFlip()
            card.isFlipped.toggle()
            markerCard = card
            return
        }
        let willReveal = !revealedIDs.contains(card.objectId) && !foundIDs.contains(card.objectId)
        if willReveal {
            HuntSoundFX.shared.playFlip()
        }
        let outcome = handleTap(objectId: card.objectId)
        switch outcome {
        case .collected, .decoy:
            card.isFlipped = true
            markerCard = card
            if case .decoy = outcome, let object = currentRound.object(id: card.objectId) {
                scheduleDelayedSpeech {
                    guard let target = self.currentTarget else { return }
                    let line = await self.prompts.line(
                        for: .decoy(revealedName: object.name, targetName: target.name),
                        context: self.promptContext
                    )
                    self.speech.speak(line, roundIndex: self.roundIndex, kind: .decoy)
                }
            }
        case .alreadyRevealed, .alreadyFound:
            if let object = currentRound.object(id: card.objectId) {
                scheduleDelayedSpeech { self.speakObjectName(object) }
            }
            if revealedIDs.contains(card.objectId) || card.isFlipped {
                card.isFlipped = true
                markerCard = card
            }
        }
    }

    func resetMarkerCardForNewRound() {
        dismissTask?.cancel()
        dismissTask = nil
        markerCard = nil
        cardMarkerId = nil
        visibleMarkers.removeAll()
    }

    private func scheduleMarkerCardDismiss() {
        guard markerCard?.isPreview != true else { return }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            guard let active = self.cardMarkerId, !self.visibleMarkers.contains(active) else { return }
            self.markerCard = nil
            self.cardMarkerId = nil
            self.startIdleChatter()
        }
    }

    private func advanceAfterCollect(found: HuntObject) async {
        stopIdleChatter()
        try? await Task.sleep(nanoseconds: Pacing.cardRevealSpeechDelay)

        let cheer = await prompts.line(
            for: .collected(targetName: found.name),
            context: promptContext
        )
        speech.speak(cheer, roundIndex: roundIndex, kind: .success)
        try? await Task.sleep(nanoseconds: Pacing.afterCheerDelay)

        if let coopLine = CoopPrompts.line(
            moment: .afterFind,
            context: promptContext,
            styleIndex: coopLineIndex
        ) {
            coopLineIndex += 1
            speech.speak(coopLine, roundIndex: roundIndex, kind: .prompt)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
        }

        if Bool.random(), markerCard == nil {
            let wonder = WonderLines.line(
                playerName: playerName,
                target: found,
                round: currentRound,
                styleIndex: wonderLineIndex
            )
            wonderLineIndex += 1
            speech.speak(wonder, roundIndex: roundIndex, kind: .prompt)
            try? await Task.sleep(nanoseconds: 1_400_000_000)
        }

        if movementPromptsEnabled, markerCard == nil, !speech.isSpeaking {
            let movement = MovementPrompts.line(
                playerName: playerName,
                helperName: helperName,
                familyPlayMode: familyPlayMode,
                styleIndex: movementLineIndex
            )
            movementLineIndex += 1
            speech.speak(movement, roundIndex: roundIndex, kind: .prompt)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
        }

        if allRequiredTargetsFound {
            await presentRoundSuccess()
            return
        }

        try? await Task.sleep(nanoseconds: Pacing.beforeNextPromptDelay)
        await speakFindPrompt()
    }

    private func presentRoundSuccess() async {
        stopIdleChatter()
        lastCompletedRoundTitle = currentRound.title
        lastCompletedRoundTargets = requiredTargets
        dismissMarkerCard()
        showRoundSuccess = true
        HuntSoundFX.shared.playComplete()

        try? await Task.sleep(nanoseconds: Pacing.roundSuccessSpeechDelay)
        let line = await prompts.line(for: .roundComplete, context: promptContext)
        speech.speak(line, roundIndex: roundIndex, kind: .success)

        if let coopLine = CoopPrompts.line(
            moment: .roundComplete,
            context: promptContext,
            styleIndex: coopLineIndex
        ) {
            coopLineIndex += 1
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            speech.speak(coopLine, roundIndex: roundIndex, kind: .success)
        }
    }

    func continueToNextRound() async {
        guard showRoundSuccess else { return }
        showRoundSuccess = false
        stopIdleChatter()
        flipSpeechTask?.cancel()
        speech.stop()

        guard hasNextRound else {
            phase = .complete
            showCollection = true
            return
        }

        roundIndex += 1
        backImages.removeAll()
        foundIDs.removeAll()
        revealedIDs.removeAll()
        shuffleSessionTargets()
        roundToken += 1
        showContentPanel = true
        resetMarkerCardForNewRound()

        await prefetch(roundIndex: roundIndex, tracking: .current)
        try? await Task.sleep(nanoseconds: Pacing.beforeNextRoundIntroDelay)
        await speakIntroAndPrompt()
        scheduleHideContentPanelIfReady()
        if manifest.rounds.indices.contains(roundIndex + 1) {
            Task { await self.prefetch(roundIndex: self.roundIndex + 1, tracking: .next) }
        }
    }

    private func speakIntroAndPrompt() async {
        guard let target = currentTarget else { return }

        if let coopLine = CoopPrompts.line(
            moment: .intro,
            context: promptContext,
            styleIndex: coopLineIndex
        ) {
            coopLineIndex += 1
            speech.speak(coopLine, roundIndex: roundIndex, kind: .prompt)
            try? await Task.sleep(nanoseconds: 1_400_000_000)
        }

        let intro = await prompts.line(
            for: .intro(targetName: target.name),
            context: promptContext
        )
        speech.speak(intro, roundIndex: roundIndex, kind: .prompt)
        updateStatusLine(for: target)
        startIdleChatter()
    }

    private func speakFindPrompt(rephrase: Bool = false) async {
        guard let target = currentTarget else { return }
        let kind: PromptKind = rephrase
            ? .findRephrase(targetName: target.name)
            : .find(targetName: target.name)
        let options = PromptLineOptions(
            avoidPhrase: rephrase ? speech.lastText : nil,
            useShortTimeout: rephrase
        )
        let line = await prompts.line(for: kind, context: promptContext, options: options)
        speech.speak(line, roundIndex: roundIndex, kind: .prompt)
        updateStatusLine(for: target)
        startIdleChatter()
    }

    private func updateStatusLine(for target: HuntObject) {
        statusLine = currentRound.isPredatorHunt ? "Track the \(target.name)" : "Find the \(target.name)"
    }

    private func speakObjectName(_ object: HuntObject) {
        speech.speak(object.name, roundIndex: roundIndex, kind: .prompt)
    }

    private func scheduleDelayedSpeech(_ delay: UInt64 = Pacing.cardRevealSpeechDelay, perform: @escaping @MainActor () async -> Void) {
        flipSpeechTask?.cancel()
        flipSpeechTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await perform()
        }
    }

    private var shouldRunIdleChatter: Bool {
        phase == .playing
            && currentTarget != nil
            && markerCard == nil
            && !isDevMenuOpen
            && !showRoundSuccess
    }

    private func startIdleChatter() {
        idleChatterTask?.cancel()
        guard shouldRunIdleChatter else { return }

        idleChatterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Pacing.idleChatterInitialDelay)
            while !Task.isCancelled {
                guard self.shouldRunIdleChatter else { break }
                await self.waitForSpeechToFinish()
                guard !Task.isCancelled, self.shouldRunIdleChatter else { break }
                self.speakIdleChatterLine()
                let interval = UInt64.random(
                    in: Pacing.idleChatterMinInterval...Pacing.idleChatterMaxInterval
                )
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func stopIdleChatter() {
        idleChatterTask?.cancel()
        idleChatterTask = nil
    }

    private func waitForSpeechToFinish() async {
        var waits = 0
        while speech.isSpeaking, waits < 120 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            waits += 1
        }
    }

    private func speakIdleChatterLine() {
        guard let target = currentTarget else { return }
        let line = IdleChatter.line(
            playerName: playerName,
            target: target,
            round: currentRound,
            familyPlayMode: familyPlayMode,
            movementPromptsEnabled: movementPromptsEnabled,
            grownUpName: grownUpName,
            helperName: helperName,
            styleIndex: idleChatterIndex
        )
        idleChatterIndex += 1
        speech.speak(line, roundIndex: roundIndex, kind: .prompt)
    }

    private func kindPersonalizationChance(_ kind: PromptKind) -> Double {
        switch kind {
        case .intro, .find, .findRephrase, .collected: return 0.35
        case .decoy, .roundComplete, .complete: return 0
        }
    }

    private func prefetch(roundIndex: Int, tracking: PrefetchTrack) async {
        guard manifest.rounds.indices.contains(roundIndex) else { return }
        let round = manifest.rounds[roundIndex]
        let objects = activeObjects(in: round)
        switch tracking {
        case .current:
            imagesLoaded = 0
            imagesTotal = objects.count
            nextImagesLoaded = 0
            nextImagesTotal = 0
        case .next:
            nextImagesLoaded = 0
            nextImagesTotal = objects.count
        }
        async let hunter: Void = prefetchHunterPortrait(for: round, applyToUI: tracking == .current)
        await withTaskGroup(of: Void.self) { group in
            for object in objects {
                group.addTask {
                    let photo = await ImageSearchService.fetchImage(for: object, in: round)
                    await MainActor.run {
                        if let photo {
                            self.faceImages["photo-\(object.id)"] = photo
                        }
                        self.faceImages[object.id] = CardTextureFactory.makeFace(
                            image: photo,
                            name: object.name,
                            emoji: object.emoji
                        )
                        switch tracking {
                        case .current:
                            self.imagesLoaded += 1
                        case .next:
                            self.nextImagesLoaded += 1
                        }
                    }
                }
            }
        }
        _ = await hunter
    }

    private func prefetchHunterPortrait(for round: HuntRound, applyToUI: Bool) async {
        guard round.isPredatorHunt, let name = round.predatorName else {
            if applyToUI { hunterPortrait = nil }
            return
        }
        let key = Self.hunterCacheKey(for: round.id)
        let emoji = round.predatorEmoji ?? "🐾"
        if let cached = faceImages[key] {
            if applyToUI { hunterPortrait = cached }
            return
        }
        let placeholder = CardTextureFactory.makeHunterPortrait(image: nil, name: name, emoji: emoji)
        faceImages[key] = placeholder
        if applyToUI { hunterPortrait = placeholder }

        let photo = await ImageSearchService.fetchImage(
            forName: name,
            in: round,
            cacheKey: key
        )
        let portrait = CardTextureFactory.makeHunterPortrait(image: photo, name: name, emoji: emoji)
        faceImages[key] = portrait
        if applyToUI, currentRound.id == round.id { hunterPortrait = portrait }
    }

    private static func hunterCacheKey(for roundId: String) -> String {
        "hunter-\(roundId)"
    }

    func prefetchPickerThumbnails(for rounds: [HuntRound]? = nil) async {
        let targetRounds = rounds ?? manifest.rounds
        guard !targetRounds.isEmpty else { return }

        if rounds == nil {
            pickerThumbnailsTotal = targetRounds.count
            pickerThumbnailsLoaded = 0
        } else {
            pickerThumbnailsTotal += targetRounds.count
        }

        let batchSize = 4
        var start = 0
        while start < targetRounds.count {
            let end = min(start + batchSize, targetRounds.count)
            let batch = Array(targetRounds[start..<end])
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for round in batch {
                    group.addTask {
                        (round.id, await Self.fetchPickerThumbnail(for: round))
                    }
                }
                for await (roundId, image) in group {
                    if let image {
                        pickerThumbnails[roundId] = image
                    }
                    pickerThumbnailsLoaded += 1
                }
            }
            start = end
        }
    }

    private static func fetchPickerThumbnail(for round: HuntRound) async -> UIImage? {
        let image: UIImage?
        if round.isPredatorHunt, let name = round.predatorName {
            image = await ImageSearchService.fetchImage(
                forName: name,
                in: round,
                cacheKey: hunterCacheKey(for: round.id)
            )
        } else if let firstTargetId = round.targets.first, let object = round.object(id: firstTargetId) {
            image = await ImageSearchService.fetchImage(for: object, in: round)
        } else if let object = round.objects.first {
            image = await ImageSearchService.fetchImage(for: object, in: round)
        } else {
            image = nil
        }
        guard let image else { return nil }
        return thumbnailSized(image)
    }

    private static func thumbnailSized(_ image: UIImage, maxDimension: CGFloat = 320) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func loadModel() async {
        modelStatus = .loading
        modelDownloadProgress = 0
        modelLoadError = nil
        modelStatus = await LLMRunner.shared.warmup { [weak self] progress in
            self?.modelDownloadProgress = progress
        }
        modelLoadError = LLMRunner.shared.lastLoadError
        if modelStatus == .ready {
            modelDownloadProgress = 1
        }
    }

    private func scheduleHideContentPanelIfReady() {
        guard imagesTotal > 0, imagesLoaded >= imagesTotal,
              modelStatus == .ready || modelStatus == .unavailable else { return }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if self.imagesLoaded >= self.imagesTotal,
               self.modelStatus == .ready || self.modelStatus == .unavailable {
                self.showContentPanel = false
            }
        }
    }

    private enum PrefetchTrack {
        case current
        case next
    }

    private func playSuccess() {
        HuntSoundFX.shared.playSuccess()
    }

    private func playError() {
        HuntSoundFX.shared.playMiss()
    }
}
