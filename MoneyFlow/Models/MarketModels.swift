import Foundation

enum MarketSignal: String, Codable {
    case buy = "BUY"
    case stay = "STAY"
    case sell = "SELL"
}

enum MarketConfidence: String, Codable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"

    func downgraded() -> MarketConfidence {
        switch self {
        case .high:
            return .medium
        case .medium, .low:
            return .low
        }
    }
}

struct MarketIndicatorScore: Identifiable, Codable {
    let id: String
    let title: String
    let valueText: String
    let score: Int
    let maxScore: Int
    let isAvailable: Bool
    let note: String?
}

struct MarketAPIIssue: Identifiable, Codable {
    let id: String
    let endpoint: String
    let url: String
    let reason: String
}

struct MarketAnalysisResult: Codable {
    let ticker: String
    let analyzedAt: Date
    let totalScore: Int
    let signal: MarketSignal
    let confidence: MarketConfidence
    let indicatorScores: [MarketIndicatorScore]
    let adjustments: [String]
    let overrideReason: String?
    let warnings: [String]
    let apiIssues: [MarketAPIIssue]
    let dataCompleteness: Int
}
