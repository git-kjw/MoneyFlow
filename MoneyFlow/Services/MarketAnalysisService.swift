import Foundation

final class MarketAnalysisService {
    private let session: URLSession
    private let finnhubAPIToken = "d7u99phr01qnv95mp0jgd7u99phr01qnv95mp0k0"

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (MoneyFlowApp)"
        ]
        self.session = URLSession(configuration: configuration)
    }

    func analyze(ticker: String) async -> MarketAnalysisResult {
        let normalizedTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedTicker.isEmpty else {
            return MarketAnalysisResult(ticker: "-", analyzedAt: Date(), recommendations: [])
        }

        guard var components = URLComponents(string: "https://finnhub.io/api/v1/stock/recommendation") else {
            return MarketAnalysisResult(ticker: normalizedTicker, analyzedAt: Date(), recommendations: [])
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: normalizedTicker),
            URLQueryItem(name: "token", value: finnhubAPIToken)
        ]

        guard let url = components.url else {
            return MarketAnalysisResult(ticker: normalizedTicker, analyzedAt: Date(), recommendations: [])
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return MarketAnalysisResult(ticker: normalizedTicker, analyzedAt: Date(), recommendations: [])
            }

            let decoded = try JSONDecoder().decode([FinnhubRecommendationResponse].self, from: data)
            let recentRecommendations = decoded
                .sorted { $0.period > $1.period }
                .prefix(5)
                .map {
                    MarketRecommendation(
                        symbol: $0.symbol,
                        period: $0.period,
                        strongBuy: $0.strongBuy,
                        buy: $0.buy,
                        hold: $0.hold,
                        sell: $0.sell,
                        strongSell: $0.strongSell
                    )
                }

            return MarketAnalysisResult(
                ticker: normalizedTicker,
                analyzedAt: Date(),
                recommendations: Array(recentRecommendations)
            )
        } catch {
            return MarketAnalysisResult(ticker: normalizedTicker, analyzedAt: Date(), recommendations: [])
        }
    }
}

private struct FinnhubRecommendationResponse: Decodable {
    let buy: Int
    let hold: Int
    let period: String
    let sell: Int
    let strongBuy: Int
    let strongSell: Int
    let symbol: String
}
