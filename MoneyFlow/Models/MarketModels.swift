import Foundation

struct MarketAnalysisResult: Codable {
    let ticker: String
    let analyzedAt: Date
    let recommendations: [MarketRecommendation]
    let insiderTransactions: [InsiderTransaction]
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

struct InsiderTransaction: Identifiable, Codable {
    let filingID: String
    let name: String
    let transactionDate: String
    let transactionCode: String
    let change: Int
    let transactionPrice: Double

    var id: String {
        "\(filingID)-\(name)-\(transactionDate)-\(transactionCode)-\(change)-\(transactionPrice)"
    }

    var sideLabel: String {
        transactionCode == "P" ? "매수" : "매도"
    }
}
