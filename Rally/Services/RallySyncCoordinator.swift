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

    // MARK: - Apply (replace collections)

    private static func apply(_ envelope: SyncEnvelope, modelContext: ModelContext) throws {
        for row in try modelContext.fetch(FetchDescriptor<TrainingSession>()) {
            modelContext.delete(row)
        }
        for row in try modelContext.fetch(FetchDescriptor<MatchEntry>()) {
            modelContext.delete(row)
        }
        for row in try modelContext.fetch(FetchDescriptor<JournalEntry>()) {
            modelContext.delete(row)
        }

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

        for dto in envelope.trainingSessions {
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

        for dto in envelope.matchEntries {
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

        for dto in envelope.journalEntries {
            let row = JournalEntry(
                date: dto.date,
                title: dto.title,
                body: dto.body,
                mood: dto.mood,
                tags: dto.tagsCSV
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty },
                focus: JournalFocus(rawValue: dto.focusRaw) ?? .general,
                promptId: dto.promptId
            )
            row.id = dto.id
            modelContext.insert(row)
        }
    }

    private static func applyAvatar(_ dto: AvatarPayload, to avatar: AvatarConfig) {
        avatar.id = dto.id
        avatar.playerName = dto.playerName
        avatar.skinToneRaw = dto.skinToneRaw
        avatar.hairStyleRaw = dto.hairStyleRaw
        avatar.hairColorHex = dto.hairColorHex
        avatar.bodyTypeRaw = dto.bodyTypeRaw
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
