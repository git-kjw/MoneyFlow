import Foundation

enum MarketAnalysisError: LocalizedError {
    case invalidTicker
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidTicker:
            return "유효한 티커를 입력해주세요."
        case .invalidResponse:
            return "시장 데이터를 불러오지 못했습니다."
        }
    }
}

final class MarketAnalysisService {
    private let session: URLSession
    private let alphaVantageAPIKey = "PL93H8M4YBC1AYZR"
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
            return fallbackResult(ticker: "-", warnings: ["유효한 티커를 입력해주세요."])
        }

        var warnings: [String] = []
        var apiIssues: [MarketAPIIssue] = []

        let yahooChart = await fetchYahooDailyBars(ticker: normalizedTicker, warnings: &warnings, apiIssues: &apiIssues)
        let finnhub = await fetchFinnhubFundamentals(ticker: normalizedTicker, warnings: &warnings, apiIssues: &apiIssues)
        let overview = await fetchOverview(ticker: normalizedTicker, apiKey: alphaVantageAPIKey, warnings: &warnings, apiIssues: &apiIssues)
        let fearGreed = await fetchFearGreedScore(warnings: &warnings, apiIssues: &apiIssues)
        let vix = await fetchVIXValue(warnings: &warnings, apiIssues: &apiIssues)

        let technical = buildTechnicalSnapshot(
            timeSeries: yahooChart.bars,
            quote: [:],
            fallbackCurrentPrice: yahooChart.regularMarketPrice
        )
        let fundamental = buildFundamentalSnapshot(
            overview: overview,
            finnhub: finnhub,
            fallback52WeekHigh: yahooChart.fiftyTwoWeekHigh,
            fallback52WeekLow: yahooChart.fiftyTwoWeekLow
        )

        var indicatorScores: [MarketIndicatorScore] = []
        var totalScore = 0
        var availableCount = 0

        let rsiScore = scoreRSI(technical.rsi)
        indicatorScores.append(rsiScore.metric)
        totalScore += rsiScore.metric.score
        if rsiScore.metric.isAvailable { availableCount += 1 }

        let macdScore = scoreMACD(macd: technical.macd, signal: technical.macdSignal, histogram: technical.macdHistogram, previousHistogram: technical.previousMACDHistogram)
        indicatorScores.append(macdScore.metric)
        totalScore += macdScore.metric.score
        if macdScore.metric.isAvailable { availableCount += 1 }

        let bollingerScore = scoreBollinger(currentPrice: technical.currentPrice, lower: technical.lowerBand, middle: technical.middleBand, upper: technical.upperBand)
        indicatorScores.append(bollingerScore.metric)
        totalScore += bollingerScore.metric.score
        if bollingerScore.metric.isAvailable { availableCount += 1 }
        if let warning = bollingerScore.warning {
            warnings.append(warning)
        }

        let smaScore = scoreSMA(currentPrice: technical.currentPrice, sma50: technical.sma50, sma200: technical.sma200)
        indicatorScores.append(smaScore.metric)
        totalScore += smaScore.metric.score
        if smaScore.metric.isAvailable { availableCount += 1 }

        let perScore = scorePER(fundamental.per)
        indicatorScores.append(perScore.metric)
        totalScore += perScore.metric.score
        if perScore.metric.isAvailable { availableCount += 1 }

        let epsScore = scoreEPSGrowth(fundamental.epsGrowth)
        indicatorScores.append(epsScore.metric)
        totalScore += epsScore.metric.score
        if epsScore.metric.isAvailable { availableCount += 1 }

        let upsideScore = scoreUpside(currentPrice: technical.currentPrice, targetPrice: fundamental.analystTargetPrice)
        indicatorScores.append(upsideScore.metric)
        totalScore += upsideScore.metric.score
        if upsideScore.metric.isAvailable { availableCount += 1 }

        let weekPositionScore = score52WeekPosition(currentPrice: technical.currentPrice, weekHigh: fundamental.week52High, weekLow: fundamental.week52Low)
        indicatorScores.append(weekPositionScore.metric)
        totalScore += weekPositionScore.metric.score
        if weekPositionScore.metric.isAvailable { availableCount += 1 }

        let vixScore = scoreVIX(vix)
        indicatorScores.append(vixScore.metric)
        totalScore += vixScore.metric.score
        if vixScore.metric.isAvailable { availableCount += 1 }

        let fearGreedScore = scoreFearGreed(fearGreed)
        indicatorScores.append(fearGreedScore.metric)
        totalScore += fearGreedScore.metric.score
        if fearGreedScore.metric.isAvailable { availableCount += 1 }

        let volumeScore = scoreVolume(changePercent: technical.changePercent, volumeRatio: technical.volumeRatio)
        indicatorScores.append(volumeScore.metric)
        totalScore += volumeScore.metric.score
        if volumeScore.metric.isAvailable { availableCount += 1 }

        let adjustmentResult = applyAdjustments(
            baseScore: totalScore,
            rsi: technical.rsi,
            histogram: technical.macdHistogram,
            currentPrice: technical.currentPrice,
            upperBand: technical.upperBand,
            lowerBand: technical.lowerBand,
            changePercent: technical.changePercent,
            volumeRatio: technical.volumeRatio,
            epsGrowth: fundamental.epsGrowth,
            per: fundamental.per,
            vix: vix,
            fearGreed: fearGreed,
            upside: upsideScore.upside
        )

        let confidence = resolveConfidence(totalScore: adjustmentResult.totalScore, availableCount: availableCount)

        let signal: MarketSignal
        if let forcedSignal = adjustmentResult.forcedSignal {
            signal = forcedSignal
        } else if adjustmentResult.totalScore >= 62 {
            signal = .buy
        } else if adjustmentResult.totalScore < 38 {
            signal = .sell
        } else {
            signal = .stay
        }

        if availableCount < 11 {
            addWarning("일부 지표 데이터가 없어 0점/중립으로 계산되었습니다.", into: &warnings)
        }
        warnings = uniqueWarnings(warnings)

        return MarketAnalysisResult(
            ticker: normalizedTicker,
            analyzedAt: Date(),
            totalScore: adjustmentResult.totalScore,
            signal: signal,
            confidence: confidence,
            indicatorScores: indicatorScores,
            adjustments: adjustmentResult.adjustments,
            overrideReason: adjustmentResult.overrideReason,
            warnings: warnings,
            apiIssues: apiIssues,
            dataCompleteness: Int((Double(availableCount) / 11.0) * 100.0)
        )
    }

    private func resolveConfidence(totalScore: Int, availableCount: Int) -> MarketConfidence {
        let base: MarketConfidence
        switch availableCount {
        case 9...:
            base = .high
        case 6...8:
            base = .medium
        default:
            base = .low
        }

        if min(abs(totalScore - 62), abs(totalScore - 38)) < 10 {
            return base.downgraded()
        }
        return base
    }

    private func applyAdjustments(
        baseScore: Int,
        rsi: Double?,
        histogram: Double?,
        currentPrice: Double?,
        upperBand: Double?,
        lowerBand: Double?,
        changePercent: Double?,
        volumeRatio: Double?,
        epsGrowth: Double?,
        per: Double?,
        vix: Double?,
        fearGreed: Double?,
        upside: Double?
    ) -> (totalScore: Int, adjustments: [String], forcedSignal: MarketSignal?, overrideReason: String?) {
        var total = baseScore
        var adjustments: [String] = []

        if let vix, let fearGreed, vix >= 40, fearGreed <= 25 {
            total += 10
            adjustments.append("+10: VIX ≥ 40 & Fear&Greed ≤ 25")
        }
        if let rsi, let currentPrice, let lowerBand, rsi <= 28, currentPrice <= lowerBand {
            total += 7
            adjustments.append("+7: RSI ≤ 28 & 하단 밴드 터치")
        }
        if let rsi, let currentPrice, let upperBand, rsi >= 72, currentPrice >= upperBand {
            total -= 10
            adjustments.append("-10: RSI ≥ 72 & 상단 밴드 돌파")
        }
        if let epsGrowth, let per, epsGrowth < 0, per > 35 {
            total -= 7
            adjustments.append("-7: EPS 역성장 & PER > 35")
        }

        if let rsi, let histogram, rsi > 75, histogram < 0 {
            return (total, adjustments, .sell, "강제 SELL: RSI > 75 & MACD Histogram < 0")
        }
        if let currentPrice, let upperBand, let changePercent, let volumeRatio,
           currentPrice >= upperBand, changePercent > 3, volumeRatio < 1 {
            return (total, adjustments, .sell, "강제 SELL: 거래량 없는 급등")
        }
        if let changePercent, let volumeRatio, changePercent < -5, volumeRatio >= 3 {
            return (total, adjustments, .sell, "강제 SELL: 공황 매도 패턴")
        }
        if let epsGrowth, let per, epsGrowth < -0.20, per > 40 {
            return (total, adjustments, .sell, "강제 SELL: 실적 급감 + 고평가")
        }
        if let rsi, let currentPrice, let lowerBand, let vix, rsi <= 28, currentPrice <= lowerBand, vix >= 30 {
            return (total, adjustments, .buy, "강제 BUY: 삼중 공포 신호")
        }
        if let fearGreed, let vix, let upside, fearGreed <= 20, vix >= 35, upside >= 0.20 {
            return (total, adjustments, .buy, "강제 BUY: 극공포 + 업사이드")
        }

        return (total, adjustments, nil, nil)
    }

    private func scoreRSI(_ rsi: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let rsi else {
            return (MarketIndicatorScore(id: "rsi", title: "RSI", valueText: "데이터 없음", score: 0, maxScore: 15, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if rsi <= 30 {
            score = 15
        } else if rsi <= 45 {
            score = 10
        } else if rsi <= 55 {
            score = 5
        } else if rsi <= 70 {
            score = 0
        } else {
            score = -10
        }
        return (MarketIndicatorScore(id: "rsi", title: "RSI", valueText: String(format: "%.2f", rsi), score: score, maxScore: 15, isAvailable: true, note: nil), rsi)
    }

    private func scoreMACD(macd: Double?, signal: Double?, histogram: Double?, previousHistogram: Double?) -> (metric: MarketIndicatorScore, rawHistogram: Double?) {
        guard let macd, let signal, let histogram, let previousHistogram else {
            return (MarketIndicatorScore(id: "macd", title: "MACD", valueText: "데이터 없음", score: 0, maxScore: 18, isAvailable: false, note: nil), nil)
        }

        var score: Int
        if histogram > 0 && histogram > previousHistogram {
            score = 15
        } else if histogram > 0 {
            score = 5
        } else if histogram < 0 && histogram > previousHistogram {
            score = -5
        } else if histogram < 0 {
            score = -15
        } else {
            score = 0
        }

        if macd > signal {
            score += 3
        } else if macd < signal {
            score -= 3
        }

        let valueText = String(format: "H %.3f / M %.3f / S %.3f", histogram, macd, signal)
        return (MarketIndicatorScore(id: "macd", title: "MACD", valueText: valueText, score: score, maxScore: 18, isAvailable: true, note: nil), histogram)
    }

    private func scoreBollinger(currentPrice: Double?, lower: Double?, middle: Double?, upper: Double?) -> (metric: MarketIndicatorScore, warning: String?) {
        guard let currentPrice, let lower, let middle, let upper, middle > 0 else {
            return (MarketIndicatorScore(id: "bollinger", title: "볼린저 밴드", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if currentPrice <= lower {
            score = 10
        } else if abs(currentPrice - middle) / middle <= 0.01 {
            score = 2
        } else if currentPrice < middle {
            score = 5
        } else if currentPrice >= upper {
            score = -10
        } else {
            score = 0
        }

        let width = (upper - lower) / middle
        let warning = width < 0.05 ? "볼린저 밴드 폭이 매우 좁습니다(변동성 확대 가능)." : nil
        let valueText = String(format: "현재 %.2f / 하단 %.2f / 중단 %.2f / 상단 %.2f", currentPrice, lower, middle, upper)
        return (MarketIndicatorScore(id: "bollinger", title: "볼린저 밴드", valueText: valueText, score: score, maxScore: 10, isAvailable: true, note: nil), warning)
    }

    private func scoreSMA(currentPrice: Double?, sma50: Double?, sma200: Double?) -> (metric: MarketIndicatorScore, raw: (Double, Double, Double)?) {
        guard let currentPrice, let sma50, let sma200 else {
            return (MarketIndicatorScore(id: "sma", title: "SMA50 / SMA200", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if currentPrice > sma50 && sma50 > sma200 {
            score = 10
        } else if currentPrice > sma50 && sma50 < sma200 {
            score = 3
        } else if currentPrice < sma50 && sma50 > sma200 {
            score = -3
        } else if currentPrice < sma50 && sma50 < sma200 {
            score = -10
        } else {
            score = 0
        }

        let valueText = String(format: "현재 %.2f / SMA50 %.2f / SMA200 %.2f", currentPrice, sma50, sma200)
        return (MarketIndicatorScore(id: "sma", title: "SMA50 / SMA200", valueText: valueText, score: score, maxScore: 10, isAvailable: true, note: nil), (currentPrice, sma50, sma200))
    }

    private func scorePER(_ per: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let per else {
            return (MarketIndicatorScore(id: "per", title: "PER", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if per <= 0 {
            score = 0
        } else if per <= 10 {
            score = 10
        } else if per <= 15 {
            score = 7
        } else if per <= 20 {
            score = 5
        } else if per <= 25 {
            score = 2
        } else if per <= 35 {
            score = 0
        } else if per <= 50 {
            score = -5
        } else {
            score = -8
        }

        return (MarketIndicatorScore(id: "per", title: "PER", valueText: String(format: "%.2f", per), score: score, maxScore: 10, isAvailable: true, note: nil), per)
    }

    private func scoreEPSGrowth(_ epsGrowth: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let epsGrowth else {
            return (MarketIndicatorScore(id: "eps", title: "EPS 성장률", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if epsGrowth >= 0.30 {
            score = 10
        } else if epsGrowth >= 0.15 {
            score = 7
        } else if epsGrowth >= 0.05 {
            score = 4
        } else if epsGrowth >= 0 {
            score = 1
        } else {
            score = -5
        }

        return (MarketIndicatorScore(id: "eps", title: "EPS 성장률", valueText: String(format: "%.2f%%", epsGrowth * 100), score: score, maxScore: 10, isAvailable: true, note: nil), epsGrowth)
    }

    private func scoreUpside(currentPrice: Double?, targetPrice: Double?) -> (metric: MarketIndicatorScore, upside: Double?) {
        guard let currentPrice, currentPrice > 0, let targetPrice else {
            return (MarketIndicatorScore(id: "upside", title: "목표주가 업사이드", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let upside = (targetPrice - currentPrice) / currentPrice
        let score: Int
        if upside >= 0.25 {
            score = 10
        } else if upside >= 0.15 {
            score = 7
        } else if upside >= 0.05 {
            score = 3
        } else if upside >= -0.05 {
            score = 0
        } else {
            score = -8
        }

        return (MarketIndicatorScore(id: "upside", title: "목표주가 업사이드", valueText: String(format: "%.2f%%", upside * 100), score: score, maxScore: 10, isAvailable: true, note: nil), upside)
    }

    private func score52WeekPosition(currentPrice: Double?, weekHigh: Double?, weekLow: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let currentPrice, let weekHigh, let weekLow, weekHigh > weekLow else {
            return (MarketIndicatorScore(id: "week52", title: "52주 위치", valueText: "데이터 없음", score: 0, maxScore: 5, isAvailable: false, note: nil), nil)
        }

        let position = (currentPrice - weekLow) / (weekHigh - weekLow)
        let score: Int
        if position <= 0.2 {
            score = 5
        } else if position <= 0.4 {
            score = 3
        } else if position <= 0.6 {
            score = 1
        } else if position <= 0.8 {
            score = 0
        } else {
            score = -3
        }

        return (MarketIndicatorScore(id: "week52", title: "52주 위치", valueText: String(format: "%.1f%%", position * 100), score: score, maxScore: 5, isAvailable: true, note: nil), position)
    }

    private func scoreVIX(_ vix: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let vix else {
            return (MarketIndicatorScore(id: "vix", title: "VIX", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if vix >= 40 {
            score = 10
        } else if vix >= 30 {
            score = 7
        } else if vix >= 20 {
            score = 3
        } else if vix >= 15 {
            score = 0
        } else {
            score = -5
        }

        return (MarketIndicatorScore(id: "vix", title: "VIX", valueText: String(format: "%.2f", vix), score: score, maxScore: 10, isAvailable: true, note: nil), vix)
    }

    private func scoreFearGreed(_ scoreValue: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let scoreValue else {
            return (MarketIndicatorScore(id: "feargreed", title: "Fear & Greed", valueText: "데이터 없음", score: 0, maxScore: 10, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if scoreValue <= 25 {
            score = 10
        } else if scoreValue <= 45 {
            score = 6
        } else if scoreValue <= 55 {
            score = 2
        } else if scoreValue <= 75 {
            score = -3
        } else {
            score = -10
        }

        return (MarketIndicatorScore(id: "feargreed", title: "Fear & Greed", valueText: String(format: "%.0f", scoreValue), score: score, maxScore: 10, isAvailable: true, note: nil), scoreValue)
    }

    private func scoreVolume(changePercent: Double?, volumeRatio: Double?) -> (metric: MarketIndicatorScore, raw: Double?) {
        guard let changePercent, let volumeRatio else {
            return (MarketIndicatorScore(id: "volume", title: "거래량 비율", valueText: "데이터 없음", score: 0, maxScore: 5, isAvailable: false, note: nil), nil)
        }

        let score: Int
        if changePercent > 0, volumeRatio >= 1.5 {
            score = 5
        } else if changePercent > 0, volumeRatio >= 1 {
            score = 2
        } else if changePercent > 0 {
            score = 0
        } else if changePercent < 0, volumeRatio < 1 {
            score = -2
        } else if changePercent < 0, volumeRatio >= 1.5 {
            score = -5
        } else {
            score = 0
        }

        let valueText = String(format: "등락률 %.2f%% / 거래량비율 %.2f", changePercent, volumeRatio)
        return (MarketIndicatorScore(id: "volume", title: "거래량 비율", valueText: valueText, score: score, maxScore: 5, isAvailable: true, note: nil), volumeRatio)
    }
}

private extension MarketAnalysisService {
    struct DailyBar {
        let date: Date
        let close: Double
        let volume: Double
    }

    struct TechnicalSnapshot {
        let currentPrice: Double?
        let changePercent: Double?
        let volumeRatio: Double?
        let rsi: Double?
        let macd: Double?
        let macdSignal: Double?
        let macdHistogram: Double?
        let previousMACDHistogram: Double?
        let sma50: Double?
        let sma200: Double?
        let lowerBand: Double?
        let middleBand: Double?
        let upperBand: Double?
    }

    struct FundamentalSnapshot {
        let per: Double?
        let epsGrowth: Double?
        let analystTargetPrice: Double?
        let week52High: Double?
        let week52Low: Double?
    }

    struct YahooChartPayload {
        let bars: [DailyBar]
        let regularMarketPrice: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
    }

    struct FinnhubFundamentalPayload {
        let per: Double?
        let epsGrowth: Double?
        let targetPrice: Double?
        let week52High: Double?
        let week52Low: Double?
    }

    func fetchYahooDailyBars(ticker: String, warnings: inout [String], apiIssues: inout [MarketAPIIssue]) async -> YahooChartPayload {
        let endpoint = "Yahoo Chart"
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=1y") else {
            addWarning("Yahoo 일봉 URL 생성 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: "URL 생성 실패", reason: "유효하지 않은 URL", into: &apiIssues)
            return YahooChartPayload(bars: [], regularMarketPrice: nil, fiftyTwoWeekHigh: nil, fiftyTwoWeekLow: nil)
        }

        do {
            let json = try await fetchJSON(url: url)
            guard let chart = json["chart"] as? [String: Any],
                  let result = chart["result"] as? [[String: Any]],
                  let first = result.first,
                  let timestamps = first["timestamp"] as? [Any],
                  let indicators = first["indicators"] as? [String: Any],
                  let quotes = indicators["quote"] as? [[String: Any]],
                  let quote = quotes.first,
                  let closeValues = quote["close"] as? [Any],
                  let volumeValues = quote["volume"] as? [Any]
            else {
                addWarning("Yahoo 일봉 데이터 파싱 실패", into: &warnings)
                addIssue(endpoint: endpoint, url: url.absoluteString, reason: "응답 구조 파싱 실패", into: &apiIssues)
                return YahooChartPayload(bars: [], regularMarketPrice: nil, fiftyTwoWeekHigh: nil, fiftyTwoWeekLow: nil)
            }

            var bars: [DailyBar] = []
            let count = min(timestamps.count, closeValues.count, volumeValues.count)
            for index in 0..<count {
                guard let timestamp = timestamps[index] as? NSNumber else { continue }
                if closeValues[index] is NSNull || volumeValues[index] is NSNull { continue }
                guard let close = (closeValues[index] as? NSNumber)?.doubleValue,
                      let volume = (volumeValues[index] as? NSNumber)?.doubleValue else { continue }
                bars.append(DailyBar(date: Date(timeIntervalSince1970: timestamp.doubleValue), close: close, volume: volume))
            }

            let sortedBars = bars.sorted { $0.date < $1.date }
            let meta = first["meta"] as? [String: Any]
            let regularMarketPrice = parseDouble(any: meta?["regularMarketPrice"])
            let fiftyTwoWeekHigh = parseDouble(any: meta?["fiftyTwoWeekHigh"])
            let fiftyTwoWeekLow = parseDouble(any: meta?["fiftyTwoWeekLow"])

            return YahooChartPayload(
                bars: sortedBars,
                regularMarketPrice: regularMarketPrice,
                fiftyTwoWeekHigh: fiftyTwoWeekHigh,
                fiftyTwoWeekLow: fiftyTwoWeekLow
            )
        } catch {
            addWarning("Yahoo 일봉 조회 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: url.absoluteString, reason: error.localizedDescription, into: &apiIssues)
            return YahooChartPayload(bars: [], regularMarketPrice: nil, fiftyTwoWeekHigh: nil, fiftyTwoWeekLow: nil)
        }
    }

    func fetchFinnhubFundamentals(ticker: String, warnings: inout [String], apiIssues: inout [MarketAPIIssue]) async -> FinnhubFundamentalPayload? {
        guard !finnhubAPIToken.isEmpty else { return nil }

        let metricEndpoint = "Finnhub stock/metric"
        let targetEndpoint = "Finnhub stock/price-target"
        guard let metricURL = URL(string: "https://finnhub.io/api/v1/stock/metric?symbol=\(ticker)&metric=all&token=\(finnhubAPIToken)"),
              let targetURL = URL(string: "https://finnhub.io/api/v1/stock/price-target?symbol=\(ticker)&token=\(finnhubAPIToken)") else {
            addIssue(endpoint: metricEndpoint, url: "URL 생성 실패", reason: "유효하지 않은 URL", into: &apiIssues)
            return nil
        }

        var per: Double?
        var epsGrowth: Double?
        var targetPrice: Double?
        var week52High: Double?
        var week52Low: Double?

        do {
            let metricJSON = try await fetchJSON(url: metricURL)
            if let errorMessage = metricJSON["error"] as? String {
                addIssue(endpoint: metricEndpoint, url: metricURL.absoluteString, reason: errorMessage, into: &apiIssues)
            } else if let metric = metricJSON["metric"] as? [String: Any] {
                per = parseDouble(any: metric["peTTM"])
                    ?? parseDouble(any: metric["peBasicExclExtraTTM"])
                    ?? parseDouble(any: metric["peInclExtraTTM"])
                epsGrowth = parseDouble(any: metric["epsGrowthQuarterlyYoy"])
                    ?? parseDouble(any: metric["epsGrowthTTMYoy"])
                targetPrice = parseDouble(any: metric["priceTargetAverage"])
                week52High = parseDouble(any: metric["52WeekHigh"])
                week52Low = parseDouble(any: metric["52WeekLow"])
            }
        } catch {
            addIssue(endpoint: metricEndpoint, url: metricURL.absoluteString, reason: error.localizedDescription, into: &apiIssues)
            addWarning("Finnhub 펀더멘털 조회 실패", into: &warnings)
        }

        do {
            let targetJSON = try await fetchJSON(url: targetURL)
            if let errorMessage = targetJSON["error"] as? String {
                addIssue(endpoint: targetEndpoint, url: targetURL.absoluteString, reason: errorMessage, into: &apiIssues)
            } else {
                targetPrice = targetPrice
                    ?? parseDouble(any: targetJSON["targetMean"])
                    ?? parseDouble(any: targetJSON["targetMedian"])
            }
        } catch {
            addIssue(endpoint: targetEndpoint, url: targetURL.absoluteString, reason: error.localizedDescription, into: &apiIssues)
        }

        return FinnhubFundamentalPayload(
            per: per,
            epsGrowth: epsGrowth,
            targetPrice: targetPrice,
            week52High: week52High,
            week52Low: week52Low
        )
    }

    func fetchTimeSeriesDaily(ticker: String, apiKey: String, warnings: inout [String]) async -> [DailyBar] {
        guard let url = buildAlphaURL(function: "TIME_SERIES_DAILY", symbol: ticker, apiKey: apiKey, extraItems: [URLQueryItem(name: "outputsize", value: "full")]) else {
            warnings.append("일봉 URL 생성 실패")
            return []
        }

        do {
            let json = try await fetchJSON(url: url)
            if let note = json["Note"] as? String {
                warnings.append("Alpha Vantage 제한: \(note)")
                return []
            }
            if let errorMessage = json["Error Message"] as? String {
                warnings.append("일봉 조회 실패: \(errorMessage)")
                return []
            }
            guard let series = json["Time Series (Daily)"] as? [String: [String: String]] else {
                warnings.append("일봉 데이터 파싱 실패")
                return []
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            let bars: [DailyBar] = series.compactMap { key, value in
                guard let date = formatter.date(from: key),
                      let close = value["4. close"].flatMap(Double.init),
                      let volume = value["5. volume"].flatMap(Double.init)
                else { return nil }
                return DailyBar(date: date, close: close, volume: volume)
            }

            return bars.sorted { $0.date < $1.date }
        } catch {
            warnings.append("일봉 조회 실패: \(error.localizedDescription)")
            return []
        }
    }

    func fetchGlobalQuote(ticker: String, apiKey: String, warnings: inout [String], apiIssues: inout [MarketAPIIssue]) async -> [String: String] {
        let endpoint = "AlphaVantage GLOBAL_QUOTE"
        guard let url = buildAlphaURL(function: "GLOBAL_QUOTE", symbol: ticker, apiKey: apiKey) else {
            addWarning("GLOBAL_QUOTE URL 생성 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: "URL 생성 실패", reason: "유효하지 않은 URL", into: &apiIssues)
            return [:]
        }

        do {
            let json = try await fetchJSON(url: url)
            if let note = json["Note"] as? String {
                _ = note
                addWarning("Alpha Vantage 호출 제한으로 일부 항목이 생략되었습니다.", into: &warnings)
                addIssue(endpoint: endpoint, url: url.absoluteString, reason: "호출 제한(무료 플랜/요청량)", into: &apiIssues)
                return [:]
            }
            if let errorMessage = json["Error Message"] as? String {
                _ = errorMessage
                addWarning("GLOBAL_QUOTE 조회 실패", into: &warnings)
                addIssue(endpoint: endpoint, url: url.absoluteString, reason: errorMessage, into: &apiIssues)
                return [:]
            }
            return (json["Global Quote"] as? [String: String]) ?? [:]
        } catch {
            addWarning("GLOBAL_QUOTE 조회 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: url.absoluteString, reason: error.localizedDescription, into: &apiIssues)
            return [:]
        }
    }

    func fetchOverview(ticker: String, apiKey: String, warnings: inout [String], apiIssues: inout [MarketAPIIssue]) async -> [String: String] {
        let endpoint = "AlphaVantage OVERVIEW"
        guard let url = buildAlphaURL(function: "OVERVIEW", symbol: ticker, apiKey: apiKey) else {
            addWarning("OVERVIEW URL 생성 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: "URL 생성 실패", reason: "유효하지 않은 URL", into: &apiIssues)
            return [:]
        }

        for attempt in 0...1 {
            do {
                let json = try await fetchJSON(url: url)
                if let note = json["Note"] as? String {
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        continue
                    }
                    _ = note
                    addWarning("Alpha Vantage 호출 제한으로 일부 항목이 생략되었습니다.", into: &warnings)
                    addIssue(endpoint: endpoint, url: url.absoluteString, reason: "호출 제한(무료 플랜/요청량)", into: &apiIssues)
                    return [:]
                }
                if let errorMessage = json["Error Message"] as? String {
                    _ = errorMessage
                    addWarning("OVERVIEW 조회 실패", into: &warnings)
                    addIssue(endpoint: endpoint, url: url.absoluteString, reason: errorMessage, into: &apiIssues)
                    return [:]
                }
                let overview = json as? [String: String] ?? [:]
                if overview.isEmpty {
                    addWarning("OVERVIEW 응답이 비어 있습니다.", into: &warnings)
                    addIssue(endpoint: endpoint, url: url.absoluteString, reason: "빈 응답", into: &apiIssues)
                }
                return overview
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    continue
                }
                addWarning("OVERVIEW 조회 실패", into: &warnings)
                addIssue(endpoint: endpoint, url: url.absoluteString, reason: error.localizedDescription, into: &apiIssues)
                return [:]
            }
        }
        return [:]
    }

    func fetchVIXValue(warnings: inout [String], apiIssues: inout [MarketAPIIssue]) async -> Double? {
        let endpoint = "Yahoo VIX Chart"
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=5d") else {
            addWarning("VIX URL 생성 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: "URL 생성 실패", reason: "유효하지 않은 URL", into: &apiIssues)
            return nil
        }

        do {
            let json = try await fetchJSON(url: url)
            guard let chart = json["chart"] as? [String: Any],
                  let result = chart["result"] as? [[String: Any]],
                  let first = result.first,
                  let indicators = first["indicators"] as? [String: Any],
                  let quote = indicators["quote"] as? [[String: Any]],
                  let closeValues = quote.first?["close"] as? [Any]
            else {
                addWarning("VIX 데이터 파싱 실패", into: &warnings)
                addIssue(endpoint: endpoint, url: url.absoluteString, reason: "응답 구조 파싱 실패", into: &apiIssues)
                return nil
            }

            let closes = closeValues.compactMap { value -> Double? in
                if value is NSNull { return nil }
                if let number = value as? NSNumber { return number.doubleValue }
                return nil
            }

            return closes.last
        } catch {
            addWarning("VIX 조회 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: url.absoluteString, reason: error.localizedDescription, into: &apiIssues)
            return nil
        }
    }

    func fetchFearGreedScore(warnings: inout [String], apiIssues: inout [MarketAPIIssue]) async -> Double? {
        let endpoint = "CNN FearGreed"
        guard let url = URL(string: "https://production.dataviz.cnn.io/index/fearandgreed/graphdata") else {
            addWarning("Fear & Greed URL 생성 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: "URL 생성 실패", reason: "유효하지 않은 URL", into: &apiIssues)
            return nil
        }

        do {
            let json = try await fetchJSON(url: url)
            guard let fearGreed = json["fear_and_greed"] as? [String: Any] else {
                addWarning("Fear & Greed 데이터 파싱 실패", into: &warnings)
                addIssue(endpoint: endpoint, url: url.absoluteString, reason: "응답 구조 파싱 실패", into: &apiIssues)
                return nil
            }
            if let score = fearGreed["score"] as? Double {
                return score
            }
            if let score = fearGreed["score"] as? NSNumber {
                return score.doubleValue
            }
            return nil
        } catch {
            addWarning("Fear & Greed 조회 실패", into: &warnings)
            addIssue(endpoint: endpoint, url: url.absoluteString, reason: error.localizedDescription, into: &apiIssues)
            return nil
        }
    }

    func addWarning(_ warning: String, into warnings: inout [String]) {
        guard !warnings.contains(warning) else { return }
        warnings.append(warning)
    }

    func uniqueWarnings(_ warnings: [String]) -> [String] {
        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }
    }

    func addIssue(endpoint: String, url: String, reason: String, into issues: inout [MarketAPIIssue]) {
        let id = "\(endpoint)|\(url)|\(reason)"
        guard !issues.contains(where: { $0.id == id }) else { return }
        issues.append(MarketAPIIssue(id: id, endpoint: endpoint, url: url, reason: reason))
    }

    func fallbackResult(ticker: String, warnings: [String]) -> MarketAnalysisResult {
        MarketAnalysisResult(
            ticker: ticker,
            analyzedAt: Date(),
            totalScore: 0,
            signal: .stay,
            confidence: .low,
            indicatorScores: [],
            adjustments: [],
            overrideReason: nil,
            warnings: uniqueWarnings(warnings),
            apiIssues: [],
            dataCompleteness: 0
        )
    }

    func buildTechnicalSnapshot(timeSeries: [DailyBar], quote: [String: String], fallbackCurrentPrice: Double? = nil) -> TechnicalSnapshot {
        let closes = timeSeries.map(\.close)
        let volumes = timeSeries.map(\.volume)

        let currentPrice = parseDouble(quote["05. price"]) ?? fallbackCurrentPrice ?? closes.last
        let changePercent = parsePercent(quote["10. change percent"]) ?? changePercentFromCloses(closes)
        let currentVolume = parseDouble(quote["06. volume"]) ?? volumes.last
        let averageVolume = average(Array(volumes.suffix(20)))
        let volumeRatio: Double? = {
            guard let currentVolume, let averageVolume, averageVolume > 0 else { return nil }
            return currentVolume / averageVolume
        }()

        let rsi = calculateRSI(closes: closes, period: 14)
        let macdData = calculateMACD(closes: closes)
        let bollinger = calculateBollinger(closes: closes, period: 20)
        let sma50 = sma(closes: closes, period: 50)
        let sma200 = sma(closes: closes, period: 200)

        return TechnicalSnapshot(
            currentPrice: currentPrice,
            changePercent: changePercent,
            volumeRatio: volumeRatio,
            rsi: rsi,
            macd: macdData.macd,
            macdSignal: macdData.signal,
            macdHistogram: macdData.histogram,
            previousMACDHistogram: macdData.previousHistogram,
            sma50: sma50,
            sma200: sma200,
            lowerBand: bollinger.lower,
            middleBand: bollinger.middle,
            upperBand: bollinger.upper
        )
    }

    func changePercentFromCloses(_ closes: [Double]) -> Double? {
        guard closes.count >= 2 else { return nil }
        let current = closes[closes.count - 1]
        let previous = closes[closes.count - 2]
        guard previous != 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    func buildFundamentalSnapshot(
        overview: [String: String],
        finnhub: FinnhubFundamentalPayload?,
        fallback52WeekHigh: Double?,
        fallback52WeekLow: Double?
    ) -> FundamentalSnapshot {
        FundamentalSnapshot(
            per: parseDouble(overview["PERatio"]) ?? finnhub?.per,
            epsGrowth: parseDouble(overview["QuarterlyEarningsGrowthYOY"]) ?? finnhub?.epsGrowth,
            analystTargetPrice: parseDouble(overview["AnalystTargetPrice"]) ?? finnhub?.targetPrice,
            week52High: parseDouble(overview["52WeekHigh"]) ?? finnhub?.week52High ?? fallback52WeekHigh,
            week52Low: parseDouble(overview["52WeekLow"]) ?? finnhub?.week52Low ?? fallback52WeekLow
        )
    }

    func fetchJSON(url: URL) async throws -> [String: Any] {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw MarketAnalysisError.invalidResponse
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw MarketAnalysisError.invalidResponse
        }
        return dictionary
    }

    func buildAlphaURL(function: String, symbol: String, apiKey: String, extraItems: [URLQueryItem] = []) -> URL? {
        var components = URLComponents(string: "https://www.alphavantage.co/query")
        components?.queryItems = [
            URLQueryItem(name: "function", value: function),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: apiKey)
        ] + extraItems
        return components?.url
    }

    func parseDouble(_ value: String?) -> Double? {
        guard let value, !value.isEmpty, value != "None", value != "-" else { return nil }
        return Double(value)
    }

    func parseDouble(any value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    func parsePercent(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value.replacingOccurrences(of: "%", with: ""))
    }

    func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func sma(closes: [Double], period: Int) -> Double? {
        guard closes.count >= period else { return nil }
        return average(Array(closes.suffix(period)))
    }

    func calculateRSI(closes: [Double], period: Int) -> Double? {
        guard closes.count > period else { return nil }
        let recent = Array(closes.suffix(period + 1))
        var gains = 0.0
        var losses = 0.0

        for index in 1..<recent.count {
            let delta = recent[index] - recent[index - 1]
            if delta > 0 {
                gains += delta
            } else {
                losses += abs(delta)
            }
        }

        let averageGain = gains / Double(period)
        let averageLoss = losses / Double(period)
        if averageLoss == 0 {
            return 100
        }
        let rs = averageGain / averageLoss
        return 100 - (100 / (1 + rs))
    }

    func calculateMACD(closes: [Double]) -> (macd: Double?, signal: Double?, histogram: Double?, previousHistogram: Double?) {
        guard closes.count >= 35 else { return (nil, nil, nil, nil) }
        guard let ema12 = ema(values: closes, period: 12),
              let ema26 = ema(values: closes, period: 26),
              ema12.count == closes.count,
              ema26.count == closes.count else {
            return (nil, nil, nil, nil)
        }

        var macdSeries: [Double] = []
        for index in 0..<closes.count {
            guard let fast = ema12[index], let slow = ema26[index] else { continue }
            macdSeries.append(fast - slow)
        }

        guard macdSeries.count >= 10,
              let signalSeries = ema(values: macdSeries, period: 9) else {
            return (nil, nil, nil, nil)
        }

        let compactSignal = signalSeries.compactMap { $0 }
        guard compactSignal.count >= 2 else {
            return (nil, nil, nil, nil)
        }

        let macd = macdSeries.last
        let signal = compactSignal.last
        let previousMACD = macdSeries.dropLast().last
        let previousSignal = compactSignal.dropLast().last

        guard let macd, let signal, let previousMACD, let previousSignal else {
            return (nil, nil, nil, nil)
        }

        return (
            macd: macd,
            signal: signal,
            histogram: macd - signal,
            previousHistogram: previousMACD - previousSignal
        )
    }

    func calculateBollinger(closes: [Double], period: Int) -> (lower: Double?, middle: Double?, upper: Double?) {
        guard closes.count >= period else {
            return (nil, nil, nil)
        }

        let window = Array(closes.suffix(period))
        guard let middle = average(window) else {
            return (nil, nil, nil)
        }

        let variance = window.reduce(0.0) { partial, close in
            partial + pow(close - middle, 2)
        } / Double(period)
        let standardDeviation = sqrt(variance)

        return (
            lower: middle - (2 * standardDeviation),
            middle: middle,
            upper: middle + (2 * standardDeviation)
        )
    }

    func ema(values: [Double], period: Int) -> [Double?]? {
        guard values.count >= period else { return nil }
        let multiplier = 2.0 / Double(period + 1)
        var result = Array<Double?>(repeating: nil, count: values.count)

        guard let initialSMA = average(Array(values.prefix(period))) else { return nil }
        result[period - 1] = initialSMA

        if values.count == period {
            return result
        }

        for index in period..<values.count {
            guard let previousEMA = result[index - 1] else { continue }
            result[index] = ((values[index] - previousEMA) * multiplier) + previousEMA
        }

        return result
    }
}
