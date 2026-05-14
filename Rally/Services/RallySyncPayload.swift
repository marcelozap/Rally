import Foundation

// MARK: - Wire format (matches `backend/src/server.js` snapshot)

struct AuthTokenResponse: Codable {
    let token: String
    let user: AuthUserPayload
}

struct AuthUserPayload: Codable {
    let id: String
    let email: String
}

struct SyncEnvelope: Codable {
    var version: Int
    var updatedAt: Date?
    var avatar: AvatarPayload
    var progress: ProgressPayload
    var trainingSessions: [TrainingPayload]
    var matchEntries: [MatchPayload]
    var journalEntries: [JournalPayload]
}

struct AvatarPayload: Codable {
    var id: UUID
    var playerName: String
    var skinToneRaw: String
    var hairStyleRaw: String
    var hairColorHex: String
    var bodyTypeRaw: String
    var equippedTopID: String
    var equippedBottomID: String
    var equippedShoesID: String
    var equippedRacketID: String
    var hasCompletedSetup: Bool

    enum CodingKeys: String, CodingKey {
        case id, playerName, skinToneRaw, hairStyleRaw, hairColorHex, bodyTypeRaw
        case equippedTopID, equippedBottomID, equippedShoesID, equippedRacketID
        case hasCompletedSetup
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idStr = try c.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idStr) ?? UUID()
        playerName = try c.decode(String.self, forKey: .playerName)
        skinToneRaw = try c.decode(String.self, forKey: .skinToneRaw)
        hairStyleRaw = try c.decode(String.self, forKey: .hairStyleRaw)
        hairColorHex = try c.decode(String.self, forKey: .hairColorHex)
        bodyTypeRaw = try c.decode(String.self, forKey: .bodyTypeRaw)
        equippedTopID = try c.decode(String.self, forKey: .equippedTopID)
        equippedBottomID = try c.decode(String.self, forKey: .equippedBottomID)
        equippedShoesID = try c.decode(String.self, forKey: .equippedShoesID)
        equippedRacketID = try c.decode(String.self, forKey: .equippedRacketID)
        hasCompletedSetup = try c.decode(Bool.self, forKey: .hasCompletedSetup)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(playerName, forKey: .playerName)
        try c.encode(skinToneRaw, forKey: .skinToneRaw)
        try c.encode(hairStyleRaw, forKey: .hairStyleRaw)
        try c.encode(hairColorHex, forKey: .hairColorHex)
        try c.encode(bodyTypeRaw, forKey: .bodyTypeRaw)
        try c.encode(equippedTopID, forKey: .equippedTopID)
        try c.encode(equippedBottomID, forKey: .equippedBottomID)
        try c.encode(equippedShoesID, forKey: .equippedShoesID)
        try c.encode(equippedRacketID, forKey: .equippedRacketID)
        try c.encode(hasCompletedSetup, forKey: .hasCompletedSetup)
    }

    init(
        id: UUID,
        playerName: String,
        skinToneRaw: String,
        hairStyleRaw: String,
        hairColorHex: String,
        bodyTypeRaw: String,
        equippedTopID: String,
        equippedBottomID: String,
        equippedShoesID: String,
        equippedRacketID: String,
        hasCompletedSetup: Bool
    ) {
        self.id = id
        self.playerName = playerName
        self.skinToneRaw = skinToneRaw
        self.hairStyleRaw = hairStyleRaw
        self.hairColorHex = hairColorHex
        self.bodyTypeRaw = bodyTypeRaw
        self.equippedTopID = equippedTopID
        self.equippedBottomID = equippedBottomID
        self.equippedShoesID = equippedShoesID
        self.equippedRacketID = equippedRacketID
        self.hasCompletedSetup = hasCompletedSetup
    }
}

struct ProgressPayload: Codable {
    var id: UUID
    var coins: Int
    var xp: Int
    var bestScore: Int
    var bestCombo: Int
    var totalSessions: Int
    var totalPerfectHits: Int
    var totalGreatHits: Int
    var totalGoodHits: Int
    var totalMisses: Int
    var dailyStreak: Int
    var lastPlayDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, coins, xp, bestScore, bestCombo, totalSessions
        case totalPerfectHits, totalGreatHits, totalGoodHits, totalMisses
        case dailyStreak, lastPlayDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idStr = try c.decode(String.self, forKey: .id)
        id = UUID(uuidString: idStr) ?? UUID()
        coins = try c.decode(Int.self, forKey: .coins)
        xp = try c.decode(Int.self, forKey: .xp)
        bestScore = try c.decode(Int.self, forKey: .bestScore)
        bestCombo = try c.decode(Int.self, forKey: .bestCombo)
        totalSessions = try c.decode(Int.self, forKey: .totalSessions)
        totalPerfectHits = try c.decode(Int.self, forKey: .totalPerfectHits)
        totalGreatHits = try c.decode(Int.self, forKey: .totalGreatHits)
        totalGoodHits = try c.decode(Int.self, forKey: .totalGoodHits)
        totalMisses = try c.decode(Int.self, forKey: .totalMisses)
        dailyStreak = try c.decode(Int.self, forKey: .dailyStreak)
        lastPlayDate = try c.decodeIfPresent(Date.self, forKey: .lastPlayDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(coins, forKey: .coins)
        try c.encode(xp, forKey: .xp)
        try c.encode(bestScore, forKey: .bestScore)
        try c.encode(bestCombo, forKey: .bestCombo)
        try c.encode(totalSessions, forKey: .totalSessions)
        try c.encode(totalPerfectHits, forKey: .totalPerfectHits)
        try c.encode(totalGreatHits, forKey: .totalGreatHits)
        try c.encode(totalGoodHits, forKey: .totalGoodHits)
        try c.encode(totalMisses, forKey: .totalMisses)
        try c.encode(dailyStreak, forKey: .dailyStreak)
        try c.encodeIfPresent(lastPlayDate, forKey: .lastPlayDate)
    }

    init(
        id: UUID,
        coins: Int,
        xp: Int,
        bestScore: Int,
        bestCombo: Int,
        totalSessions: Int,
        totalPerfectHits: Int,
        totalGreatHits: Int,
        totalGoodHits: Int,
        totalMisses: Int,
        dailyStreak: Int,
        lastPlayDate: Date?
    ) {
        self.id = id
        self.coins = coins
        self.xp = xp
        self.bestScore = bestScore
        self.bestCombo = bestCombo
        self.totalSessions = totalSessions
        self.totalPerfectHits = totalPerfectHits
        self.totalGreatHits = totalGreatHits
        self.totalGoodHits = totalGoodHits
        self.totalMisses = totalMisses
        self.dailyStreak = dailyStreak
        self.lastPlayDate = lastPlayDate
    }
}

struct TrainingPayload: Codable {
    var id: UUID
    var date: Date
    var durationMinutes: Int
    var drillType: String
    var intensity: Int
    var notes: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idStr = try c.decode(String.self, forKey: .id)
        id = UUID(uuidString: idStr) ?? UUID()
        date = try c.decode(Date.self, forKey: .date)
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        drillType = try c.decode(String.self, forKey: .drillType)
        intensity = try c.decode(Int.self, forKey: .intensity)
        notes = try c.decode(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(drillType, forKey: .drillType)
        try c.encode(intensity, forKey: .intensity)
        try c.encode(notes, forKey: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, durationMinutes, drillType, intensity, notes
    }

    init(id: UUID, date: Date, durationMinutes: Int, drillType: String, intensity: Int, notes: String) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.drillType = drillType
        self.intensity = intensity
        self.notes = notes
    }
}

struct MatchPayload: Codable {
    var id: UUID
    var date: Date
    var opponentName: String
    var location: String
    var surfaceRaw: String
    var resultWon: Bool
    var setsCSV: String
    var notes: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idStr = try c.decode(String.self, forKey: .id)
        id = UUID(uuidString: idStr) ?? UUID()
        date = try c.decode(Date.self, forKey: .date)
        opponentName = try c.decode(String.self, forKey: .opponentName)
        location = try c.decode(String.self, forKey: .location)
        surfaceRaw = try c.decode(String.self, forKey: .surfaceRaw)
        resultWon = try c.decode(Bool.self, forKey: .resultWon)
        setsCSV = try c.decode(String.self, forKey: .setsCSV)
        notes = try c.decode(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(opponentName, forKey: .opponentName)
        try c.encode(location, forKey: .location)
        try c.encode(surfaceRaw, forKey: .surfaceRaw)
        try c.encode(resultWon, forKey: .resultWon)
        try c.encode(setsCSV, forKey: .setsCSV)
        try c.encode(notes, forKey: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, opponentName, location, surfaceRaw, resultWon, setsCSV, notes
    }

    init(
        id: UUID,
        date: Date,
        opponentName: String,
        location: String,
        surfaceRaw: String,
        resultWon: Bool,
        setsCSV: String,
        notes: String
    ) {
        self.id = id
        self.date = date
        self.opponentName = opponentName
        self.location = location
        self.surfaceRaw = surfaceRaw
        self.resultWon = resultWon
        self.setsCSV = setsCSV
        self.notes = notes
    }
}

struct JournalPayload: Codable {
    var id: UUID
    var date: Date
    var title: String
    var body: String
    var mood: Int
    var tagsCSV: String
    var focusRaw: String
    var promptId: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idStr = try c.decode(String.self, forKey: .id)
        id = UUID(uuidString: idStr) ?? UUID()
        date = try c.decode(Date.self, forKey: .date)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        mood = try c.decode(Int.self, forKey: .mood)
        tagsCSV = try c.decode(String.self, forKey: .tagsCSV)
        focusRaw = try c.decode(String.self, forKey: .focusRaw)
        promptId = try c.decode(String.self, forKey: .promptId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(mood, forKey: .mood)
        try c.encode(tagsCSV, forKey: .tagsCSV)
        try c.encode(focusRaw, forKey: .focusRaw)
        try c.encode(promptId, forKey: .promptId)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, title, body, mood, tagsCSV, focusRaw, promptId
    }

    init(
        id: UUID,
        date: Date,
        title: String,
        body: String,
        mood: Int,
        tagsCSV: String,
        focusRaw: String,
        promptId: String
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
        self.mood = mood
        self.tagsCSV = tagsCSV
        self.focusRaw = focusRaw
        self.promptId = promptId
    }
}

struct APIErrorPayload: Codable {
    let error: String
}

enum RallyAPIError: Error {
    case invalidURL
    case unauthorized
    case http(Int, String?)
    case decoding
}
