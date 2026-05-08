import Foundation

struct MarketAnalysisResult: Codable {
    let ticker: String
    let analyzedAt: Date
    let recommendations: [MarketRecommendation]
}

struct MarketRecommendation: Identifiable, Codable {
    let symbol: String
    let period: String
    let strongBuy: Int
    let buy: Int
    let hold: Int
    let sell: Int
    let strongSell: Int

    var id: String { "\(symbol)-\(period)" }
}
