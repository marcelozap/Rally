import Foundation
import SwiftData

// MARK: - Revision Store

enum RallySyncRevisionStore {
    private static let key = "rally.sync.currentServerRevision"

    static func load(defaults: UserDefaults = .standard) -> Int? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.integer(forKey: key)
    }

    static func save(_ revision: Int?, defaults: UserDefaults = .standard) {
        guard let revision else { return }
        defaults.set(revision, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Pull/push full player snapshot with the Rally API (SwiftData ↔ JSON).
@MainActor
enum RallySyncCoordinator {

    static func pull(modelContext: ModelContext) async throws {
        guard let token = KeychainStore.shared.token else {
            throw RallyAPIError.unauthorized
        }
        let response = try await RallyAPIClient.fetchSyncWithRevision(token: token)
        RallySyncRevisionStore.save(response.revision)
        try apply(response.envelope, modelContext: modelContext)
        try modelContext.save()
    }

    static func push(modelContext: ModelContext, enforceAvatarRevision: Bool = false) async throws {
        guard let token = KeychainStore.shared.token else { return }
        let envelope = try encode(modelContext: modelContext)
        let expectedRevision = enforceAvatarRevision ? RallySyncRevisionStore.load() : nil
        let response = try await RallyAPIClient.putSync(
            token: token,
            envelope: envelope,
            expectedRevision: expectedRevision
        )
        RallySyncRevisionStore.save(response.revision)

        // Server merge-back: if a second device pushed first, the server
        // reconciled our PlayerProgress numerics with max-wins and returned
        // the merged result. Apply just the progress side locally so we
        // don't lose another device's accrued totals on the next push.
        if let merged = response.merged,
           let progressRows = try? modelContext.fetch(FetchDescriptor<PlayerProgress>()),
           let progress = progressRows.first
        {
            applyProgress(merged.progress, to: progress)
            try? modelContext.save()
        }
    }

    /// Soft-fail push for UI hooks (avatar save, etc.).
    static func pushIfAuthenticated(modelContext: ModelContext, enforceAvatarRevision: Bool = false) async {
        guard KeychainStore.shared.token != nil else { return }
        do {
            try await push(modelContext: modelContext, enforceAvatarRevision: enforceAvatarRevision)
        } catch let conflict as RallyAPIClient.RevisionConflict {
            #if DEBUG
            print("Rally sync avatar revision conflict. Pull before retrying avatar save. serverRevision=\(conflict.serverRevision)")
            #endif
        } catch {
            #if DEBUG
            print("Rally sync push failed: \(error)")
            #endif
        }
    }

    // MARK: - Encode

    private static func encode(modelContext: ModelContext) throws -> SyncEnvelope {
        let avatars = try modelContext.fetch(FetchDescriptor<AvatarConfig>())
        guard let avatar = avatars.first else { throw RallyAPIError.decoding }

        let progresses = try modelContext.fetch(FetchDescriptor<PlayerProgress>())
        guard let progress = progresses.first else { throw RallyAPIError.decoding }

        let trainings = try modelContext.fetch(FetchDescriptor<TrainingSession>())
        let matches = try modelContext.fetch(FetchDescriptor<MatchEntry>())
        let journals = try modelContext.fetch(FetchDescriptor<JournalEntry>())

        let avatarPayload = AvatarPayload(
            id: avatar.id,
            playerName: avatar.playerName,
            skinToneRaw: avatar.skinToneRaw,
            hairStyleRaw: avatar.hairStyleRaw,
            hairColorHex: avatar.hairColorHex,
            bodyTypeRaw: avatar.bodyTypeRaw,
            athletePresetRaw: avatar.athletePresetRaw,
            equippedTopID: avatar.equippedTopID,
            equippedBottomID: avatar.equippedBottomID,
            equippedShoesID: avatar.equippedShoesID,
            equippedRacketID: avatar.equippedRacketID,
            hasCompletedSetup: avatar.hasCompletedSetup
        )

        let progressPayload = ProgressPayload(
            id: progress.id,
            coins: progress.coins,
            xp: progress.xp,
            bestScore: progress.bestScore,
            bestCombo: progress.bestCombo,
            totalSessions: progress.totalSessions,
            totalPerfectHits: progress.totalPerfectHits,
            totalGreatHits: progress.totalGreatHits,
            totalGoodHits: progress.totalGoodHits,
            totalMisses: progress.totalMisses,
            dailyStreak: progress.dailyStreak,
            lastPlayDate: progress.lastPlayDate
        )

        let trainingPayloads = trainings.map {
            TrainingPayload(
                id: $0.id,
                date: $0.date,
                durationMinutes: $0.durationMinutes,
                drillType: $0.drillType,
                intensity: $0.intensity,
                notes: $0.notes
            )
        }

        let matchPayloads = matches.map {
            MatchPayload(
                id: $0.id,
                date: $0.date,
                opponentName: $0.opponentName,
                location: $0.location,
                surfaceRaw: $0.surfaceRaw,
                resultWon: $0.resultWon,
                setsCSV: $0.setsCSV,
                notes: $0.notes
            )
        }

        let journalPayloads = journals.map {
            JournalPayload(
                id: $0.id,
                date: $0.date,
                title: $0.title,
                body: $0.body,
                mood: $0.mood,
                tagsCSV: $0.tagsCSV,
                focusRaw: $0.focusRaw,
                promptId: $0.promptId
            )
        }

        return SyncEnvelope(
            version: 1,
            updatedAt: Date(),
            avatar: avatarPayload,
            progress: progressPayload,
            trainingSessions: trainingPayloads,
            matchEntries: matchPayloads,
            journalEntries: journalPayloads
        )
    }

    // MARK: - Apply (id-based merge)

    /// Merges the server envelope into local rows by `id`.
    ///
    /// This used to delete every local TrainingSession/MatchEntry/JournalEntry
    /// and re-insert the server's copy wholesale, which had two data-loss modes:
    /// 1. A `pull()` racing ahead of a not-yet-pushed local save (e.g. a
    ///    foreground refresh right after writing a journal entry) silently
    ///    discarded that row.
    /// 2. Fields the payload doesn't carry (`photoData`, journal rally metrics,
    ///    `courtName`/`gearCSV`, `sourceRaw`) were wiped even for rows the
    ///    server already knew.
    ///
    /// Now: matching ids are updated in place (payload-covered fields only),
    /// unknown ids are inserted, and local rows the server hasn't seen are
    /// kept — the next `push()` uploads them. Trade-off: server-side deletions
    /// no longer propagate; doing that safely needs tombstones in the API.
    private static func apply(_ envelope: SyncEnvelope, modelContext: ModelContext) throws {
        let avatarRows = try modelContext.fetch(FetchDescriptor<AvatarConfig>())
        let avatar = avatarRows.first ?? AvatarConfig()
        if avatarRows.isEmpty {
            modelContext.insert(avatar)
        }
        applyAvatar(envelope.avatar, to: avatar)

        let progressRows = try modelContext.fetch(FetchDescriptor<PlayerProgress>())
        let progress = progressRows.first ?? PlayerProgress()
        if progressRows.isEmpty {
            modelContext.insert(progress)
        }
        applyProgress(envelope.progress, to: progress)

        let trainingByID = firstWinsByID(try modelContext.fetch(FetchDescriptor<TrainingSession>()), id: \.id)
        for dto in envelope.trainingSessions {
            if let row = trainingByID[dto.id] {
                row.date = dto.date
                row.durationMinutes = dto.durationMinutes
                row.drillType = dto.drillType
                row.intensity = dto.intensity
                row.notes = dto.notes
            } else {
                let row = TrainingSession(
                    date: dto.date,
                    durationMinutes: dto.durationMinutes,
                    drillType: dto.drillType,
                    intensity: dto.intensity,
                    notes: dto.notes
                )
                row.id = dto.id
                modelContext.insert(row)
            }
        }

        let matchByID = firstWinsByID(try modelContext.fetch(FetchDescriptor<MatchEntry>()), id: \.id)
        for dto in envelope.matchEntries {
            if let row = matchByID[dto.id] {
                row.date = dto.date
                row.opponentName = dto.opponentName
                row.location = dto.location
                row.surfaceRaw = (CourtSurface(rawValue: dto.surfaceRaw) ?? .hard).rawValue
                row.resultWon = dto.resultWon
                row.setsCSV = SetScore.encode(SetScore.decode(dto.setsCSV))
                row.notes = dto.notes
                // photoData is local-only (not in MatchPayload) — leave untouched.
            } else {
                let row = MatchEntry(
                    date: dto.date,
                    opponentName: dto.opponentName,
                    location: dto.location,
                    surface: CourtSurface(rawValue: dto.surfaceRaw) ?? .hard,
                    resultWon: dto.resultWon,
                    sets: SetScore.decode(dto.setsCSV),
                    notes: dto.notes
                )
                row.id = dto.id
                modelContext.insert(row)
            }
        }

        let journalByID = firstWinsByID(try modelContext.fetch(FetchDescriptor<JournalEntry>()), id: \.id)
        for dto in envelope.journalEntries {
            let tags = dto.tagsCSV
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if let row = journalByID[dto.id] {
                row.date = dto.date
                row.title = dto.title
                row.body = dto.body
                row.mood = dto.mood
                row.tagsCSV = tags.joined(separator: ",")
                row.focusRaw = (JournalFocus(rawValue: dto.focusRaw) ?? .general).rawValue
                row.promptId = dto.promptId
                // photoData, sourceRaw, rallyScore/rallyMaxCombo/rallyAccuracyPct,
                // courtName, gearCSV are local-only (not in JournalPayload) —
                // leave untouched.
            } else {
                let row = JournalEntry(
                    date: dto.date,
                    title: dto.title,
                    body: dto.body,
                    mood: dto.mood,
                    tags: tags,
                    focus: JournalFocus(rawValue: dto.focusRaw) ?? .general,
                    promptId: dto.promptId
                )
                row.id = dto.id
                modelContext.insert(row)
            }
        }
    }

    /// Index rows by id, tolerating (impossible-in-practice) duplicate ids
    /// instead of crashing like `Dictionary(uniqueKeysWithValues:)` would.
    private static func firstWinsByID<Row>(_ rows: [Row], id: KeyPath<Row, UUID>) -> [UUID: Row] {
        Dictionary(rows.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func applyAvatar(_ dto: AvatarPayload, to avatar: AvatarConfig) {
        avatar.id = dto.id
        avatar.playerName = dto.playerName
        avatar.skinToneRaw = dto.skinToneRaw
        avatar.hairStyleRaw = dto.hairStyleRaw
        avatar.hairColorHex = dto.hairColorHex
        avatar.bodyTypeRaw = dto.bodyTypeRaw
        if let raw = dto.athletePresetRaw, let preset = RallyAthletePreset(rawValue: raw) {
            avatar.athletePreset = preset
        }
        avatar.equippedTopID = dto.equippedTopID
        avatar.equippedBottomID = dto.equippedBottomID
        avatar.equippedShoesID = dto.equippedShoesID
        avatar.equippedRacketID = dto.equippedRacketID
        avatar.hasCompletedSetup = dto.hasCompletedSetup
    }

    private static func applyProgress(_ dto: ProgressPayload, to progress: PlayerProgress) {
        progress.id = dto.id
        progress.coins = dto.coins
        progress.xp = dto.xp
        progress.bestScore = dto.bestScore
        progress.bestCombo = dto.bestCombo
        progress.totalSessions = dto.totalSessions
        progress.totalPerfectHits = dto.totalPerfectHits
        progress.totalGreatHits = dto.totalGreatHits
        progress.totalGoodHits = dto.totalGoodHits
        progress.totalMisses = dto.totalMisses
        progress.dailyStreak = dto.dailyStreak
        progress.lastPlayDate = dto.lastPlayDate
    }
}
