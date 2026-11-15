import Foundation

// JSON shapes of the FastAPI backend (snake_case keys are converted automatically).

enum Lang: String, Codable, CaseIterable, Identifiable {
    case zh, en, fr, es
    var id: String { rawValue }

    /// BCP-47 voice for text-to-speech.
    var voice: String {
        switch self {
        case .zh: "zh-CN"
        case .en: "en-US"
        case .fr: "fr-FR"
        case .es: "es-ES"
        }
    }

    /// The language's name in itself.
    var selfName: String {
        switch self {
        case .zh: "简体中文"
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        }
    }

    /// Best guess at the device language, for screens shown before we know the user.
    static var device: Lang {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return Lang(rawValue: code) ?? .en
    }
}

enum Level: String, Codable, CaseIterable {
    case new, learning, familiar, mastered
    var bars: Int { [.new: 0, .learning: 1, .familiar: 2, .mastered: 3][self]! }
}

enum Gender: String, Codable {
    case m, f, mf
    case none = ""
}

enum Skill: String, Codable {
    case vocab, form, context
}

struct Me: Codable, Equatable {
    var id: String
    var native: Lang
    var target: Lang
    var onboarded: Bool
    var dailyGoal: Int
    var email: String?
    var name: String?
    var picture: String?
}

struct AuthConfig: Codable {
    var enabled: Bool
    var providers: [String]
}

struct Progress: Codable, Equatable {
    var mastery: Int
    var level: Level
    var due: Double?
    var reps: Int
    var lapses: Int
}

struct WordCard: Codable, Identifiable, Equatable {
    var id: String
    var word: String
    var pos: String
    var gender: Gender
    var difficulty: Double
    var difficultyLevel: Int
    var topic: String
    var meaning: String
    var example: String
    var exampleTranslation: String
    /// Added by the learner from a quiz: level "Custom", swipe deck only.
    var custom: Bool?
    var mastery: Int
    var level: Level
    var due: Double?
    var reps: Int
    var lapses: Int

    mutating func apply(_ p: Progress) {
        mastery = p.mastery; level = p.level; due = p.due; reps = p.reps; lapses = p.lapses
    }
}

struct Option: Codable, Hashable {
    var text: String
    var translation: String?
}

struct Question: Codable, Identifiable {
    enum Kind: String, Codable { case fill, next }
    var id: String
    var kind: Kind
    var skill: Skill
    var difficultyLevel: Int
    var prompt: String
    var translation: String
    var options: [Option]
    var mastery: Int
    var level: Level

    /// The aligned 4-language content has plain ids (f01, n01); course questions have dashes.
    var legacy: Bool { !id.contains("-") }
}

struct AnswerResult: Codable {
    var correct: Bool
    var answer: String
    var fullSentence: String
    var translation: String
    /// Why the correct answer is right.
    var explanation: String?
    /// Why the learner's choice is wrong (nil when they were right).
    var choiceExplanation: String?
    var before: Progress
    var after: Progress
}

/// Tap-to-translate: the prompt cut into plain text and words with their meanings.
struct WordToken: Codable, Hashable {
    var text: String
    var word: Bool
    var lemma: String?
    var meaning: String?
    var lemmaMeaning: String?
    var pos: String?
    var added: Bool?
}

struct QuestionWords: Codable {
    var text: String
    var tokens: [WordToken]
}

struct ReviewResult: Codable {
    var grade: String
    var before: Progress
    var after: Progress
}

struct LevelCounts: Codable {
    var new: Int, learning: Int, familiar: Int, mastered: Int
    subscript(_ l: Level) -> Int {
        switch l {
        case .new: new
        case .learning: learning
        case .familiar: familiar
        case .mastered: mastered
        }
    }
}

struct HomeData: Codable {
    struct Today: Codable { var done: Int; var goal: Int }
    struct Words: Codable { var total: Int; var due: Int; var new: Int; var levels: LevelCounts }
    struct Quiz: Codable { var total: Int; var due: Int; var new: Int; var mistakes: Int; var levels: LevelCounts }
    var native: Lang
    var target: Lang
    var leveled: Bool
    var level: Int
    var levelScore: Double
    var streak: Int
    var today: Today
    var words: Words
    var quiz: Quiz
}
