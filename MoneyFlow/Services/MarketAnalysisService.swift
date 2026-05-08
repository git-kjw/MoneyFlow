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
            return MarketAnalysisResult(ticker: "-", analyzedAt: Date(), recommendations: [], insiderTransactions: [])
        }

        async let recommendations = fetchRecommendations(for: normalizedTicker)
        async let insiderTransactions = fetchInsiderTransactions(for: normalizedTicker)

        return MarketAnalysisResult(
            ticker: normalizedTicker,
            analyzedAt: Date(),
            recommendations: await recommendations,
            insiderTransactions: await insiderTransactions
        )
    }

    private func fetchRecommendations(for ticker: String) async -> [MarketRecommendation] {
        do {
            guard let data = try await request(path: "stock/recommendation", ticker: ticker) else {
                return []
            }

            let decoded = try JSONDecoder().decode([FinnhubRecommendationResponse].self, from: data)
            return decoded
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
        } catch {
            return []
        }
    }

    private func fetchInsiderTransactions(for ticker: String) async -> [InsiderTransaction] {
        do {
            guard let data = try await request(path: "stock/insider-transactions", ticker: ticker) else {
                return []
            }

            let decoded = try JSONDecoder().decode(FinnhubInsiderTransactionsResponse.self, from: data)
            return decoded.data
                .filter {
                    let code = $0.transactionCode.uppercased()
                    return code == "P" || code == "S"
                }
                .sorted { lhs, rhs in
                    let leftDate = Self.dateFormatter.date(from: lhs.transactionDate) ?? .distantPast
                    let rightDate = Self.dateFormatter.date(from: rhs.transactionDate) ?? .distantPast
                    return leftDate > rightDate
                }
                .prefix(10)
                .map {
                    InsiderTransaction(
                        filingID: $0.id,
                        name: $0.name,
                        transactionDate: $0.transactionDate,
                        transactionCode: $0.transactionCode.uppercased(),
                        change: $0.change,
                        transactionPrice: $0.transactionPrice
                    )
                }
        } catch {
            return []
        }
    }

    private func request(path: String, ticker: String) async throws -> Data? {
        guard var components = URLComponents(string: "https://finnhub.io/api/v1/\(path)") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker),
            URLQueryItem(name: "token", value: finnhubAPIToken)
        ]

        guard let url = components.url else {
            return nil
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        return data
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

private struct FinnhubInsiderTransactionsResponse: Decodable {
    let data: [FinnhubInsiderTransaction]
}

private struct FinnhubInsiderTransaction: Decodable {
    let change: Int
    let id: String
    let name: String
    let transactionCode: String
    let transactionDate: String
    let transactionPrice: Double
}

extension MarketAnalysisService {
    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
