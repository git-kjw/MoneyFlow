import SwiftUI
import Charts

struct MarketAnalysisView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var tickerInput: String = ""
    @State private var result: MarketAnalysisResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var recentTickers: [String] = []

    private let recommendationColumns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    private let recentTickersKey = "MarketAnalysisRecentTickers"

    private var displayRecommendations: [MarketRecommendation] {
        guard let result else { return [] }
        return result.recommendations.sorted { left, right in
            let leftDate = periodDate(from: left.period) ?? .distantPast
            let rightDate = periodDate(from: right.period) ?? .distantPast
            return leftDate < rightDate
        }
    }

    private var latestRecommendation: MarketRecommendation? {
        displayRecommendations.last
    }

    private var quickTickers: [String] {
        if recentTickers.isEmpty {
            return ["APPL", "NOW", "MSFT", "TSLA", "AMZN"]
        }
        return recentTickers
    }

    private var chartPoints: [RecommendationChartPoint] {
        Array(displayRecommendations.enumerated()).flatMap { index, recommendation -> [RecommendationChartPoint] in
            return [
                RecommendationChartPoint(period: recommendation.period, xIndex: index, series: .strongBuy, value: recommendation.strongBuy),
                RecommendationChartPoint(period: recommendation.period, xIndex: index, series: .buy, value: recommendation.buy),
                RecommendationChartPoint(period: recommendation.period, xIndex: index, series: .hold, value: recommendation.hold),
                RecommendationChartPoint(period: recommendation.period, xIndex: index, series: .sell, value: recommendation.sell),
                RecommendationChartPoint(period: recommendation.period, xIndex: index, series: .strongSell, value: recommendation.strongSell)
            ]
        }
    }

    private func points(for series: RecommendationSeries) -> [RecommendationChartPoint] {
        chartPoints.filter { $0.series == series }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    inputSection
                    summarySection
                    trendChartSection
                    latestSummarySection
                }
                .padding()
            }
            .navigationTitle("시장분석")
            .onAppear {
                loadRecentTickers()
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("분석 설정")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("티커")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("", text: $tickerInput)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Button {
                        analyzeTicker()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("분석")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickTickers, id: \.self) { ticker in
                        Button(ticker) {
                            tickerInput = ticker
                            analyzeTicker()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var summarySection: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        if let result {
            VStack(alignment: .leading, spacing: 6) {
                Text(result.ticker)
                    .font(.headline)
                Text(result.analyzedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("최신 5개 기간 추이 표시")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var trendChartSection: some View {
        if let result {
            if result.recommendations.isEmpty {
                Text("추천 데이터가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("추천 추이")
                        .font(.headline)

                    Chart {
                        ForEach(points(for: .strongBuy)) { point in
                            LineMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(by: .value("의견", RecommendationSeries.strongBuy.title))
                            PointMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .foregroundStyle(by: .value("의견", RecommendationSeries.strongBuy.title))
                        }
                        ForEach(points(for: .buy)) { point in
                            LineMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(by: .value("의견", RecommendationSeries.buy.title))
                            PointMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .foregroundStyle(by: .value("의견", RecommendationSeries.buy.title))
                        }
                        ForEach(points(for: .hold)) { point in
                            LineMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(by: .value("의견", RecommendationSeries.hold.title))
                            PointMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .foregroundStyle(by: .value("의견", RecommendationSeries.hold.title))
                        }
                        ForEach(points(for: .sell)) { point in
                            LineMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(by: .value("의견", RecommendationSeries.sell.title))
                            PointMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .foregroundStyle(by: .value("의견", RecommendationSeries.sell.title))
                        }
                        ForEach(points(for: .strongSell)) { point in
                            LineMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(by: .value("의견", RecommendationSeries.strongSell.title))
                            PointMark(
                                x: .value("기간", point.xIndex),
                                y: .value("수치", point.value)
                            )
                            .foregroundStyle(by: .value("의견", RecommendationSeries.strongSell.title))
                        }
                    }
                    .chartForegroundStyleScale([
                        RecommendationSeries.strongBuy.title: RecommendationSeries.strongBuy.color,
                        RecommendationSeries.buy.title: RecommendationSeries.buy.color,
                        RecommendationSeries.hold.title: RecommendationSeries.hold.color,
                        RecommendationSeries.sell.title: RecommendationSeries.sell.color,
                        RecommendationSeries.strongSell.title: RecommendationSeries.strongSell.color
                    ])
                    .chartXAxis {
                        AxisMarks(values: Array(displayRecommendations.indices)) { value in
                            AxisValueLabel {
                                if let index = value.as(Int.self), displayRecommendations.indices.contains(index) {
                                    Text(displayRecommendations[index].period)
                                }
                            }
                            AxisTick()
                            AxisGridLine()
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 240)

                    legendSection
                }
                .padding()
                .background(Color.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var latestSummarySection: some View {
        if let latestRecommendation {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("최신 값 요약")
                        .font(.headline)
                    Spacer()
                    Text(latestRecommendation.period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: recommendationColumns, alignment: .leading, spacing: 8) {
                    countItem(title: "강력매수", value: latestRecommendation.strongBuy, color: .green)
                    countItem(title: "매수", value: latestRecommendation.buy, color: .mint)
                    countItem(title: "보유", value: latestRecommendation.hold, color: .orange)
                    countItem(title: "매도", value: latestRecommendation.sell, color: .red)
                    countItem(title: "강력매도", value: latestRecommendation.strongSell, color: .pink)
                }
            }
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func countItem(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(color)
        }
    }

    private func analyzeTicker() {
        let ticker = tickerInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !ticker.isEmpty else {
            errorMessage = "티커를 입력해주세요."
            return
        }

        addRecentTicker(ticker)
        isLoading = true
        errorMessage = nil

        Task {
            let analyzed = await dataManager.analyzeMarket(for: ticker)
            await MainActor.run {
                result = analyzed
                if analyzed.recommendations.isEmpty {
                    errorMessage = "추천 데이터를 불러오지 못했습니다."
                }
                isLoading = false
            }
        }
    }

    private func periodDate(from period: String) -> Date? {
        Self.periodFormatter.date(from: period)
    }

    private func loadRecentTickers() {
        guard let saved = UserDefaults.standard.array(forKey: recentTickersKey) as? [String] else {
            recentTickers = []
            return
        }
        recentTickers = Array(saved.filter { !$0.isEmpty }.prefix(10))
    }

    private func addRecentTicker(_ ticker: String) {
        var updated = recentTickers.filter { $0 != ticker }
        updated.insert(ticker, at: 0)
        recentTickers = Array(updated.prefix(10))
        UserDefaults.standard.set(recentTickers, forKey: recentTickersKey)
    }

    private var legendSection: some View {
        HStack(spacing: 12) {
            ForEach(RecommendationSeries.allCases, id: \.self) { series in
                HStack(spacing: 4) {
                    Circle()
                        .fill(series.color)
                        .frame(width: 8, height: 8)
                    Text(series.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

#Preview {
    MarketAnalysisView()
        .environmentObject(DataManager())
}

private struct RecommendationChartPoint: Identifiable {
    let period: String
    let xIndex: Int
    let series: RecommendationSeries
    let value: Int

    var id: String { "\(series.rawValue)-\(period)" }
}

private enum RecommendationSeries: String, CaseIterable {
    case strongBuy
    case buy
    case hold
    case sell
    case strongSell

    var title: String {
        switch self {
        case .strongBuy: return "강력매수"
        case .buy: return "매수"
        case .hold: return "유지"
        case .sell: return "매도"
        case .strongSell: return "강력매도"
        }
    }

    var color: Color {
        switch self {
        case .strongBuy: return .green
        case .buy: return .mint
        case .hold: return .orange
        case .sell: return .red
        case .strongSell: return .pink
        }
    }
}
