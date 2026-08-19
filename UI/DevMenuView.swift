import SwiftUI

struct DevMenuView: View {
    @ObservedObject var engine: HuntEngine
    var onClose: () -> Void

    @State private var llmTestResult: String?
    @State private var llmTestBusy = false
    @State private var llmWorkingSeconds = 0
    @State private var llmWorkingTimer: Task<Void, Never>?
    @State private var previewMarkerNumber = 1
    @State private var remoteReloadBusy = false

    private var groups: [String] {
        var seen: [String] = []
        for round in engine.manifest.rounds {
            let group = round.categoryGroup ?? "Categories"
            if !seen.contains(group) {
                seen.append(group)
            }
        }
        return seen
    }

    private var markerCountBinding: Binding<Int> {
        Binding(
            get: { engine.activeMarkerCount },
            set: { engine.setMarkerCount($0) }
        )
    }

    private var markerCountLabel: String {
        if engine.activeMarkerCount == 0 {
            return "Default (\(engine.manifest.resolvedMarkerCount))"
        }
        return "\(engine.activeMarkerCount)"
    }

    private var activeObjectCount: Int {
        engine.activeObjects(in: engine.currentRound).count
    }

    private var modelStatusLabel: String {
        #if targetEnvironment(simulator)
        let simNote = "Simulator: voice model runs on CPU (slow). AR hunt needs a real device.\n"
        #else
        let simNote = ""
        #endif

        switch engine.modelStatus {
        case .idle, .loading:
            if engine.modelDownloadProgress > 0 {
                return simNote + "Loading SmolLM2… \(Int(engine.modelDownloadProgress * 100))%"
            }
            return simNote + "Loading SmolLM2…"
        case .ready:
            return simNote + "SmolLM2 ready — prompts get AI flavor."
        case .unavailable:
            if let error = engine.modelLoadError {
                return simNote + error
            }
            return simNote + "SmolLM2 unavailable — using canned lines."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Pick a hunt mode to start fresh. Wild Cat and Prehistoric hunts use prey-tracking prompts like Predator hunts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Markers per round") {
                    Stepper(value: markerCountBinding, in: 0...24) {
                        HStack {
                            Text("Active markers")
                            Spacer()
                            Text(markerCountLabel)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Slider(
                        value: Binding(
                            get: { Double(engine.activeMarkerCount) },
                            set: { engine.setMarkerCount(Int($0.rounded())) }
                        ),
                        in: 0...24,
                        step: 1
                    )

                    Text("Uses marker-01 through marker-\(String(format: "%02d", engine.resolvedMarkerLimit)). Set 0 for manifest default (\(engine.manifest.resolvedMarkerCount)). Current round has \(activeObjectCount) cards.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Player") {
                    TextField("Player name", text: Binding(
                        get: { engine.playerName },
                        set: { engine.setPlayerName($0) }
                    ))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                    Text("Used occasionally in spoken lines and idle chatter while you hunt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Test idle line") {
                        llmTestResult = engine.testIdleChatter(speak: true)
                    }
                    .disabled(engine.phase != .playing || engine.currentTarget == nil)
                }

                familyPlaySection

                remoteCatalogSection

                voiceModelSection

                cardPreviewSection

                Section("Cards") {
                    Toggle("Auto-flip cards", isOn: $engine.autoFlipCards)
                    Text("Cards zoom in when they appear, then flip automatically after a short pause. Tap still works if you want to flip early.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Audio") {
                    Button("Test flip sound") { HuntSoundFX.shared.playFlip() }
                    Button("Test success sound") { HuntSoundFX.shared.playSuccess() }
                    Button("Test miss sound") { HuntSoundFX.shared.playMiss() }
                    Text("Uses bundled tones plus alert sounds (works with silent switch). Raise volume with the side buttons while this screen is open.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(groups, id: \.self) { group in
                    Section(group) {
                        ForEach(Array(engine.manifest.rounds.enumerated()), id: \.element.id) { index, round in
                            if round.categoryGroup ?? "Categories" == group {
                                categoryRow(index: index, round: round)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dev Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
            }
        }
    }

    private var familyPlaySection: some View {
        Section("Family play") {
            Picker("Mode", selection: Binding(
                get: { engine.familyPlayMode },
                set: { engine.setFamilyPlayMode($0) }
            )) {
                ForEach(FamilyPlayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            TextField("Grown-up name (optional)", text: Binding(
                get: { engine.grownUpName },
                set: { engine.setGrownUpName($0) }
            ))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

            TextField("Helper name (optional)", text: Binding(
                get: { engine.helperName },
                set: { engine.setHelperName($0) }
            ))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

            Toggle("Movement prompts", isOn: Binding(
                get: { engine.movementPromptsEnabled },
                set: { engine.setMovementPromptsEnabled($0) }
            ))

            Stepper(value: Binding(
                get: { engine.targetsPerRound },
                set: { engine.setTargetsPerRound($0) }
            ), in: 1...4) {
                HStack {
                    Text("Targets per hunt")
                    Spacer()
                    Text("\(engine.targetsPerRound)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Toggle("Shuffle targets", isOn: Binding(
                get: { engine.shuffleTargets },
                set: { engine.setShuffleTargets($0) }
            ))

            Text("Co-op lines are spoken only — no extra UI. Set targets to 1 for a mini hunt. Shuffle picks random finds each session.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Test co-op line") {
                llmTestResult = engine.testCoopLine(speak: true)
            }
            .disabled(engine.familyPlayMode == .solo)

            Button("Test wonder line") {
                llmTestResult = engine.testWonderLine(speak: true)
            }
            .disabled(engine.phase != .playing || engine.currentTarget == nil)
        }
    }

    private var remoteCatalogSection: some View {
        Section("Remote catalog") {
            let config = ContentLoader.loadRemoteConfig()
            Text("Bundled config: \(config.enabled ? "enabled" : "disabled") · version \(config.manifestVersion)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !config.manifestURL.isEmpty {
                Text(config.manifestURL)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("Set manifestURL in Resources/remote-config.json to a GitHub raw JSON URL.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !engine.remoteCatalogStatus.isEmpty {
                Text(engine.remoteCatalogStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button(remoteReloadBusy ? "Reloading…" : "Reload remote catalog") {
                remoteReloadBusy = true
                Task {
                    llmTestResult = await engine.reloadRemoteCatalog(forceRefresh: true)
                    remoteReloadBusy = false
                }
            }
            .disabled(remoteReloadBusy)
        }
    }

    private var cardPreviewSection: some View {
        Section("Card preview") {
            Text("Test marker cards without AR — works on Simulator. Tap outside or ✕ to close. Respects auto-flip setting.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Stepper(value: $previewMarkerNumber, in: 1...max(engine.resolvedMarkerLimit, 1)) {
                HStack {
                    Text("Marker")
                    Spacer()
                    Text(String(format: "%02d", previewMarkerNumber))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if let name = engine.previewObjectName(for: previewMarkerNumber) {
                Text("Card: \(name) · \(engine.currentRound.title)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No card assigned to marker \(String(format: "%02d", previewMarkerNumber)) in this round.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Button("Show card (face down)") {
                engine.previewMarkerCard(markerNumber: previewMarkerNumber)
                onClose()
            }
            .disabled(engine.previewObjectName(for: previewMarkerNumber) == nil)

            Button("Show card (face up)") {
                engine.previewMarkerCard(markerNumber: previewMarkerNumber, flipped: true)
                onClose()
            }
            .disabled(engine.previewObjectName(for: previewMarkerNumber) == nil)

            if let target = engine.currentTarget, let number = target.markerNumber {
                Button("Preview current target (\(target.name))") {
                    engine.previewMarkerCard(markerNumber: number)
                    onClose()
                }
            }
        }
    }

    private var voiceModelSection: some View {
        Section("Voice model") {
            Text(modelStatusLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(llmTestBusy ? workingLabel : "Reload model") {
                runModelTask {
                    await engine.reloadVoiceModel()
                    switch engine.modelStatus {
                    case .ready: return "Model reloaded and ready."
                    case .unavailable:
                        return engine.modelLoadError ?? "Model unavailable — using canned lines."
                    case .loading: return "Model still loading…"
                    case .idle: return "Model idle."
                    }
                }
            }
            .disabled(llmTestBusy || engine.modelStatus == .loading)

            ForEach(LLMTestPrompt.allCases) { test in
                llmButton("\(test.label) (LLM + speak)", test: test, useLLM: true, speak: true)
            }
            .disabled(llmTestBusy || engine.modelStatus != .ready)

            Divider()

            llmButton("Find (canned + speak)", test: .find, useLLM: false, speak: true)
            llmButton("Find (LLM, silent)", test: .find, useLLM: true, speak: false)
                .disabled(llmTestBusy || engine.modelStatus != .ready)

            if let llmTestResult {
                Text(llmTestResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var workingLabel: String {
        if llmWorkingSeconds > 0 {
            return "Working… \(llmWorkingSeconds)s (sim CPU is slow)"
        }
        return "Working…"
    }

    private func llmButton(_ title: String, test: LLMTestPrompt, useLLM: Bool, speak: Bool) -> some View {
        Button(title) {
            runModelTask {
                if useLLM {
                    return await engine.testPrompt(test, speak: speak)
                }
                return engine.testCannedPrompt(test, speak: speak)
            }
        }
        .disabled(llmTestBusy || (useLLM && engine.modelStatus != .ready))
    }

    private func runModelTask(_ work: @escaping () async -> String) {
        llmTestBusy = true
        llmWorkingSeconds = 0
        llmWorkingTimer?.cancel()
        llmWorkingTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                llmWorkingSeconds += 1
            }
        }
        Task {
            let line = await work()
            llmWorkingTimer?.cancel()
            llmWorkingTimer = nil
            llmTestResult = line
            llmTestBusy = false
        }
    }

    @ViewBuilder
    private func categoryRow(index: Int, round: HuntRound) -> some View {
        Button {
            Task { await engine.startNewGame(categoryIndex: index) }
            onClose()
        } label: {
            HStack(spacing: 12) {
                if round.isPredatorHunt {
                    Text(round.predatorEmoji ?? "🐾")
                        .font(.title2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(round.title)
                        .foregroundStyle(.primary)
                    if round.isPredatorHunt {
                        Text("Prey: \(round.targets.map { round.object(id: $0)?.name ?? $0 }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(round.targets.map { round.object(id: $0)?.name ?? $0 }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if index == engine.roundIndex, engine.phase == .playing {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.2), in: Capsule())
                }
            }
        }
    }
}
